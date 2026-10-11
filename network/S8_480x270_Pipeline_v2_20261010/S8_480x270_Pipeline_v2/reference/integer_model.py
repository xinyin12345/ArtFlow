"""Pure NumPy integer S8 graph executor; audit_scales are never executed."""

import collections
import hashlib
import json
from pathlib import Path

import numpy as np

try:
    from .integer_ops import I32_MAX, _integer, _qrange, _shift, conv2d_int, requantize, residual_add
except ImportError:
    from integer_ops import I32_MAX, _integer, _qrange, _shift, conv2d_int, requantize, residual_add


def _sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


class IntegerS8:
    def __init__(self, export_dir, tile_rows=8):
        self.export_dir = Path(export_dir)
        self.tile_rows = _integer(tile_rows, "tile_rows")
        if self.tile_rows < 1:
            raise ValueError("tile_rows must be positive")
        with (self.export_dir / "graph.json").open("r", encoding="utf-8") as stream:
            self.graph = json.load(stream)
        if self.graph.get("format") != "s8_bn_integer_reference" or self.graph.get("format_version") != 1:
            raise ValueError("unsupported integer graph format/version")
        if self.graph.get("input_name") != "input.rgb8" or self.graph.get("output_name") != "output.rgb8":
            raise ValueError("graph must use input.rgb8/output.rgb8")
        parameters = self.export_dir / "model_int.npz"
        if self.graph.get("params_sha256") != _sha256(parameters):
            raise ValueError("model_int.npz SHA256 does not match graph.json")
        self.params = {}
        with np.load(str(parameters), allow_pickle=False) as archive:
            for name in archive.files:
                value = archive[name]
                if value.dtype.kind not in "iu":
                    raise TypeError("non-integer parameter array: " + name)
                value = value.copy()
                value.setflags(write=False)
                self.params[name] = value
        self.nodes = self.graph.get("nodes")
        if not isinstance(self.nodes, list) or not self.nodes:
            raise ValueError("graph nodes must be a nonempty list")
        self._uses = collections.Counter()
        self._validate_graph()

    def _parameter(self, node, field, dtype):
        name = node.get(field)
        if not isinstance(name, str) or name not in self.params:
            raise ValueError("missing parameter reference: " + field)
        value = self.params[name]
        if value.dtype != np.dtype(dtype):
            raise TypeError("parameter {} must be {}".format(name, dtype))
        if value.size == 0:
            raise ValueError("empty parameter: " + name)
        return value

    def _validate_graph(self):
        channels = {"input.rgb8": 3}
        for node in self.nodes:
            if not isinstance(node, dict):
                raise TypeError("each node must be a dictionary")
            name, kind = node.get("name"), node.get("kind")
            if not isinstance(name, str) or not name or name in channels:
                raise ValueError("node output names must be unique nonempty strings")
            if kind not in ("conv", "requant", "add", "nearest2"):
                raise ValueError("unsupported integer node kind: " + str(kind))
            predecessors = [node.get("input")]
            if kind == "add":
                predecessors.append(node.get("skip"))
            if any(not isinstance(p, str) or p not in channels for p in predecessors):
                raise ValueError("node inputs must refer to earlier graph outputs")
            self._uses.update(predecessors)
            ci = channels[predecessors[0]]
            if kind == "conv":
                weight = self._parameter(node, "weight", "int8")
                bias = self._parameter(node, "bias", "int32")
                if weight.ndim != 4 or bias.shape != (weight.shape[0],):
                    raise ValueError("invalid convolution parameter shapes")
                groups = _integer(node.get("groups"), "groups")
                stride, padding = _integer(node.get("stride"), "stride"), _integer(node.get("padding"), "padding")
                if groups not in (1, ci) or weight.shape[1] * groups != ci or weight.shape[0] % groups:
                    raise ValueError("convolution group/channel mismatch")
                if stride < 1 or padding not in (0, 1):
                    raise ValueError("invalid convolution stride/padding")
                bounds = node.get("accumulator_abs_bound")
                if not isinstance(bounds, list) or len(bounds) != weight.shape[0]:
                    raise ValueError("conv requires one accumulator bound per output channel")
                for bound in bounds:
                    if not 0 <= _integer(bound, "accumulator bound") <= I32_MAX:
                        raise ValueError("declared accumulator bound must be within signed INT32")
                co = weight.shape[0]
            elif kind in ("requant", "add"):
                _shift(node.get("shift"))
                _qrange(node.get("qmin"), node.get("qmax"))
                fields = ("main_multiplier", "skip_multiplier") if kind == "add" else ("multiplier",)
                for field in fields:
                    multiplier = self._parameter(node, field, "int64")
                    if multiplier.ndim != 1 or multiplier.size not in (1, ci):
                        raise ValueError("multiplier must contain one or Cout integer values")
                    if int(multiplier.min()) <= 0:
                        raise ValueError("graph scale multipliers must be positive")
                if kind == "add" and channels[predecessors[1]] != ci:
                    raise ValueError("residual input channel counts differ")
                if kind == "requant" and node.get("rounding") not in ("half_up", "nearest_even"):
                    raise ValueError("unsupported graph rounding rule")
                co = ci
            else:
                co = ci
            channels[name] = co
        output = self.graph["output_name"]
        if output not in channels or channels[output] != 3:
            raise ValueError("graph must produce three-channel output.rgb8")

    def forward(self, rgb_nchw_uint8, trace=False):
        rgb = np.asarray(rgb_nchw_uint8)
        if rgb.dtype != np.uint8:
            raise TypeError("integer model input must be uint8 RGB")
        if rgb.ndim != 4 or rgb.shape[0] < 1 or rgb.shape[1] != 3:
            raise ValueError("input must have nonempty N x 3 x H x W shape")
        height, width = rgb.shape[-2:]
        if min(height, width) < 16 or height % 8 or width % 8:
            raise ValueError("input H/W must be multiples of 8 and at least 16")
        values = {"input.rgb8": rgb.copy()}
        remaining = self._uses.copy()
        output_name = self.graph["output_name"]
        for node in self.nodes:
            name, kind, source = node["name"], node["kind"], values[node["input"]]
            if kind == "conv":
                value = conv2d_int(source, self.params[node["weight"]], self.params[node["bias"]],
                                   stride=node["stride"], padding=node["padding"], groups=node["groups"], tile_rows=self.tile_rows)
                observed = np.abs(value).max(axis=(0, 2, 3))
                if np.any(observed > np.asarray(node["accumulator_abs_bound"], dtype=np.int64)):
                    raise OverflowError("actual accumulator exceeds exported bound at " + name)
            elif kind == "requant":
                value = requantize(source, self.params[node["multiplier"]], node["shift"], node["qmin"], node["qmax"], node["rounding"])
                if node["qmin"] >= 0 and node["qmax"] <= 255:
                    value = value.astype(np.uint8)
                elif node["qmin"] >= -128 and node["qmax"] <= 127:
                    value = value.astype(np.int8)
            elif kind == "add":
                value = residual_add(source, values[node["skip"]], self.params[node["main_multiplier"]],
                                     self.params[node["skip_multiplier"]], node["shift"], node["qmin"], node["qmax"])
                if node["qmin"] >= -128 and node["qmax"] <= 127:
                    value = value.astype(np.int8)
            else:
                value = source.repeat(2, axis=2).repeat(2, axis=3)
            if name == output_name:
                if int(value.min()) < 0 or int(value.max()) > 255:
                    raise OverflowError("final RGB codes are outside uint8")
                value = value.astype(np.uint8)
            values[name] = value
            if not trace:
                inputs = [node["input"]] + ([node["skip"]] if kind == "add" else [])
                for predecessor in inputs:
                    remaining[predecessor] -= 1
                    if remaining[predecessor] == 0 and predecessor != output_name:
                        del values[predecessor]
        output = values[output_name]
        if output.shape != rgb.shape:
            raise ValueError("integer graph changed the RGB output dimensions")
        return (output, values) if trace else output

    __call__ = forward
