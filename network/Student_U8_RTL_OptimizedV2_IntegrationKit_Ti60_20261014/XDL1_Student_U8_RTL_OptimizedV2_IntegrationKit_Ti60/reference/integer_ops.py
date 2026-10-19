"""Checked integer-only primitives for the S8 CPU reference.

Compatible with Python 3.7 / NumPy 1.15. No floating point convolution,
dequantization, division, or framework kernels are used in these functions.
INT64 is a calculation container; convolution results must fit signed INT32.
"""

import numbers

import numpy as np


I64_MIN = -(1 << 63)
I64_MAX = (1 << 63) - 1
I32_MIN = -(1 << 31)
I32_MAX = (1 << 31) - 1


def _integer(value, name):
    if isinstance(value, (bool, np.bool_)) or not isinstance(value, numbers.Integral):
        raise TypeError(name + " must be an integer")
    return int(value)


def _shift(value):
    value = _integer(value, "shift")
    if value < 0 or value > 62:
        raise ValueError("shift must be between 0 and 62")
    return value


def _array(value, name):
    value = np.asarray(value)
    if value.dtype.kind not in "iu":
        raise TypeError(name + " must contain integer values, not bool or float")
    if value.size == 0:
        raise ValueError(name + " must not be empty")
    if int(value.min()) < I64_MIN or int(value.max()) > I64_MAX:
        raise OverflowError(name + " does not fit signed INT64")
    return value.astype(np.int64, copy=False)


def _range(value):
    return int(value.min()), int(value.max())


def _qrange(qmin, qmax):
    qmin, qmax = _integer(qmin, "qmin"), _integer(qmax, "qmax")
    if qmin > qmax:
        raise ValueError("qmin must be <= qmax")
    if qmin < I64_MIN or qmax > I64_MAX:
        raise OverflowError("output code range exceeds INT64")
    return qmin, qmax


def _multiplier(value, x):
    value = _array(value, "multiplier")
    # Export parameters are either one shared value or one value per NCHW C.
    # One-dimensional standalone test vectors retain elementwise semantics.
    if value.ndim == 1 and x.ndim >= 2:
        if value.size not in (1, x.shape[1]):
            raise ValueError("multiplier length must be 1 or the channel count")
        value = value.reshape((1, value.size) + (1,) * (x.ndim - 2))
    try:
        return np.broadcast_to(value, x.shape)
    except ValueError:
        raise ValueError("multiplier cannot broadcast to the input shape")


def _checked_multiply(x, multiplier):
    """Check before multiplying, including unusual extreme integer tests."""
    multiplier = _multiplier(multiplier, x)
    xmin, xmax = _range(x)
    mmin, mmax = _range(multiplier)
    products = (xmin * mmin, xmin * mmax, xmax * mmin, xmax * mmax)
    if min(products) < I64_MIN or max(products) > I64_MAX:
        # Global extrema may belong to different channels. Verify actual
        # element pairs with bounded Python-integer chunks before rejecting.
        iterator = np.nditer([x, multiplier], flags=["external_loop", "buffered"],
                             op_flags=[["readonly"], ["readonly"]], buffersize=65536)
        for values, factors in iterator:
            exact = values.astype(object) * factors.astype(object)
            if int(exact.min()) < I64_MIN or int(exact.max()) > I64_MAX:
                raise OverflowError("requantization product exceeds INT64")
    return x * multiplier


def _checked_add(a, b):
    if a.shape != b.shape:
        raise ValueError("integer addition requires equal tensor shapes")
    amin, amax = _range(a)
    bmin, bmax = _range(b)
    if amin + bmin < I64_MIN or amax + bmax > I64_MAX:
        positive = b > 0
        negative = b < 0
        if np.any(a[positive] > I64_MAX - b[positive]):
            raise OverflowError("integer addition exceeds INT64 maximum")
        if np.any(a[negative] < I64_MIN - b[negative]):
            raise OverflowError("integer addition exceeds INT64 minimum")
    return a + b


def round_shift_half_up(v, shift):
    """floor((v + 2**(shift-1))/2**shift), ties towards +infinity.

    The positive rounding offset is checked before addition. This deliberately
    rejects a full-width value whose offset would overflow the INT64 contract.
    Shift zero performs no addition, avoiding a negative shift expression.
    """
    v, shift = _array(v, "value"), _shift(shift)
    if shift == 0:
        return v.copy()
    offset = 1 << (shift - 1)
    if int(v.max()) > I64_MAX - offset:
        raise OverflowError("half-up rounding offset exceeds INT64")
    return (v + offset) // (1 << shift)


def round_shift_even(v, shift):
    """Round a signed fixed-point number to nearest, ties to even.

    Quotient/remainder avoids negating INT64_MIN or adding a full-width
    rounding offset. For shift>=1, quotient+1 is provably within INT64.
    """
    v, shift = _array(v, "value"), _shift(shift)
    if shift == 0:
        return v.copy()
    divisor, half = 1 << shift, 1 << (shift - 1)
    quotient = v // divisor
    remainder = v % divisor
    increment = (remainder > half) | ((remainder == half) & ((quotient & 1) != 0))
    return quotient + increment.astype(np.int64)


def requantize(acc, multiplier, shift, qmin, qmax, rounding="half_up"):
    acc = _array(acc, "accumulator")
    shift = _shift(shift)
    qmin, qmax = _qrange(qmin, qmax)
    product = _checked_multiply(acc, multiplier)
    if rounding == "half_up":
        rounded = round_shift_half_up(product, shift)
    elif rounding in ("nearest_even", "even"):
        rounded = round_shift_even(product, shift)
    else:
        raise ValueError("rounding must be half_up or nearest_even")
    return np.clip(rounded, qmin, qmax).astype(np.int64, copy=False)


def residual_add(acc, skip, main_multiplier, skip_multiplier, shift, qmin=-128, qmax=127):
    """Align full-width branches, add, then round and saturate exactly once."""
    acc, skip = _array(acc, "main accumulator"), _array(skip, "skip codes")
    shift = _shift(shift)
    qmin, qmax = _qrange(qmin, qmax)
    if acc.shape != skip.shape:
        raise ValueError("residual branches must have the same shape")
    main = _checked_multiply(acc, main_multiplier)
    identity = _checked_multiply(skip, skip_multiplier)
    total = _checked_add(main, identity)
    return np.clip(round_shift_half_up(total, shift), qmin, qmax).astype(np.int64, copy=False)


def conv2d_int(x, w, bias, stride=1, padding=0, groups=1, tile_rows=8):
    """NCHW/OIHW integer cross-correlation, reflection padding, checked S32.

    Supports ordinary convolution and depthwise groups=Cin (including a
    depthwise output multiplier). Tiles materialize only a bounded number
    of output rows. Every matrix product and bias addition is INT64.
    """
    x, w, bias = _array(x, "input"), _array(w, "weight"), _array(bias, "bias")
    stride, padding = _integer(stride, "stride"), _integer(padding, "padding")
    groups, tile_rows = _integer(groups, "groups"), _integer(tile_rows, "tile_rows")
    if x.ndim != 4 or w.ndim != 4:
        raise ValueError("input/weight must have NCHW/OIHW rank 4")
    if min(x.shape) < 1 or min(w.shape) < 1:
        raise ValueError("convolution dimensions must be positive")
    if stride < 1 or tile_rows < 1 or padding not in (0, 1):
        raise ValueError("stride/tile_rows must be positive; reflection padding must be 0 or 1")
    batch, channels, height, width = x.shape
    outputs, per_group, kh, kw = w.shape
    if groups not in (1, channels) or channels % groups or outputs % groups:
        raise ValueError("groups must be 1 or Cin and divide Cout")
    if per_group != channels // groups or bias.shape != (outputs,):
        raise ValueError("weight input channels or bias shape do not match convolution")
    if padding and min(height, width) <= padding:
        raise ValueError("reflection padding needs H/W larger than the padding")
    oh, ow = (height + 2 * padding - kh) // stride + 1, (width + 2 * padding - kw) // stride + 1
    if min(oh, ow) < 1:
        raise ValueError("kernel is larger than the padded input")
    xmin, xmax = _range(x)
    wmin, wmax = _range(w)
    max_x, max_w = max(abs(xmin), abs(xmax)), max(abs(wmin), abs(wmax))
    # Make the absolute-weight sum safe before using an INT64 reduction.
    fan_in = per_group * kh * kw
    if max_w * fan_in > I64_MAX:
        raise OverflowError("absolute weight sum cannot be proven safe in INT64")
    weight_sums = np.abs(w).reshape(outputs, -1).sum(axis=1, dtype=np.int64)
    for channel in range(outputs):
        if max_x * int(weight_sums[channel]) + abs(int(bias[channel])) > I64_MAX:
            raise OverflowError("convolution MAC plus bias cannot be proven safe in INT64")
    if padding:
        padded = np.pad(x, ((0, 0), (0, 0), (padding, padding), (padding, padding)), mode="reflect")
    else:
        padded = x
    s = padded.strides
    windows = np.lib.stride_tricks.as_strided(
        padded, shape=(batch, channels, oh, ow, kh, kw),
        strides=(s[0], s[1], s[2] * stride, s[3] * stride, s[2], s[3]))
    result = np.empty((batch, outputs, oh, ow), dtype=np.int64)
    flat_weight = w.reshape(outputs, -1)
    group_outputs = outputs // groups
    for n in range(batch):
        for top in range(0, oh, tile_rows):
            bottom = min(top + tile_rows, oh)
            rows = (bottom - top) * ow
            if groups == 1:
                columns = windows[n, :, top:bottom].transpose(1, 2, 0, 3, 4).reshape(rows, fan_in)
                product = columns.dot(flat_weight.T)
                product += bias[None, :]
                result[n, :, top:bottom] = product.reshape(bottom - top, ow, outputs).transpose(2, 0, 1)
            else:
                for channel in range(channels):
                    start, end = channel * group_outputs, (channel + 1) * group_outputs
                    columns = windows[n, channel, top:bottom].reshape(rows, fan_in)
                    product = columns.dot(flat_weight[start:end].T)
                    product += bias[None, start:end]
                    result[n, start:end, top:bottom] = product.reshape(bottom - top, ow, group_outputs).transpose(2, 0, 1)
    minimum, maximum = _range(result)
    if minimum < I32_MIN or maximum > I32_MAX:
        raise OverflowError("convolution output exceeds signed INT32 accumulator range")
    return result
