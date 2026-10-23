"""Repack existing exact INT8 weights for the 72-MAC pipeline; no quantization.

Use after generate_glass_int8.py for a compatible graph. --check verifies the
currently installed ROMs without writing them. Model replacement requires a
fresh integer-reference regression and a new implementation, not a live write.
"""
from pathlib import Path
import argparse
import json
import re
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = ROOT/'network/glass_5_20epochs_sum8192_480x270_input3x3_res32_r4_int8/parameters'


def encode(parameters, architecture):
    layers = architecture['layers']
    assert len(layers) == 22, 'Expected the existing 22-layer graph'
    rows, descriptions = [], []
    for index, layer in enumerate(layers):
        weight = parameters[layer['name']+'.weight']
        k, ci, co = layer['kernel'], layer['ci'], layer['co']
        dw = layer['groups'] != 1
        assert weight.shape == (co, 1 if dw else ci, k, k)
        assert np.issubdtype(weight.dtype, np.integer)
        assert int(weight.min()) >= -128 and int(weight.max()) <= 127
        if dw:
            assert k == 3 and ci == co and co % 8 == 0
        elif index == 0:
            assert (ci, co, k) == (3, 8, 3)
        elif index == 21:
            assert (ci, co, k) == (8, 3, 5)
        else:
            assert k in (1, 3) and ci % 8 == 0 and co % 8 == 0
        base = len(rows)
        steps = 1 if dw else 3 if index == 0 else 9 if index == 21 else k*k*layer['ng']
        for og in range(layer['ogs']):
            for step in range(steps):
                lanes = np.zeros(72, dtype=np.int64)
                if dw:
                    for oc in range(8):
                        for tap in range(9):
                            lanes[oc*9+tap] = weight[og*8+oc, 0, tap//3, tap%3]
                elif index == 0:
                    for oc in range(8):
                        for tap in range(3):
                            for ic in range(3):
                                lanes[oc*9+tap*3+ic] = weight[oc, ic, step, tap]
                elif index == 21:
                    for oc in range(3):
                        for ic in range(24):
                            tap = step*3+ic//8
                            if tap < 25:
                                lanes[oc*24+ic] = weight[oc, ic%8, tap//5, tap%5]
                else:
                    tap, ig = divmod(step, layer['ng'])
                    for oc in range(8):
                        for ic in range(8):
                            lanes[oc*9+ic] = weight[og*8+oc, ig*8+ic, tap//k, tap%k]
                rows.append(sum((int(value)&255) << (8*i) for i, value in enumerate(lanes)))
        descriptions.append(dict(layer=index, name=layer['name'], base=base, steps=steps))
    assert len(rows) <= 128, 'Packed weight ROM capacity exceeded'
    files = {
        'packed_weights.mem': ''.join(f'{v:0144x}\n' for v in rows+[0]*(128-len(rows))),
        'packed_layers.vh': 'case(layer_index)\n'+''.join(
            f"{d['layer']}:begin wbase<={d['base']};steps<={d['steps']};end\n"
            for d in descriptions)+'default:begin end\nendcase\n',
    }
    return files, dict(words=len(rows), bits_per_word=576, physical_depth=128, layers=descriptions)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--parameters', type=Path, default=DEFAULT)
    parser.add_argument('--architecture', type=Path, default=ROOT/'rtl/cnn/glass_int8/architecture.json')
    parser.add_argument('--output', type=Path, default=ROOT/'rtl/cnn/glass_int8')
    parser.add_argument('--core', type=Path, default=ROOT/'rtl/cnn/glass_int8/glass_int8.v',
                        help='Generic core whose exported RGB output coefficients are regenerated')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    with np.load(args.parameters/'model_int8.npz', allow_pickle=False) as parameters:
        files, description = encode(parameters, json.loads(args.architecture.read_text()))
        # These are model output-scale coefficients, not learned convolution
        # weights or a glass-specific operator. Keep their arithmetic generic
        # and regenerate the constants together with every model replacement.
        original_core = args.core.read_text()
        updated_core = original_core
        for name, key, bits in [('RM','rgb.multiplier',28),('RB','rgb.bias',32)]:
            values = [int(v) for v in parameters[key]]
            assert len(values)==3 and all(0<=v<(1<<(bits-1)) for v in values)
            expression = f"lane==0?{bits}'sd{values[0]}:lane==1?{bits}'sd{values[1]}:{bits}'sd{values[2]}"
            updated_core, count = re.subn(
                rf'(localparam signed \[{bits-1}:0\] {name}=)[^;]+;',
                lambda m: m[1]+expression+';', updated_core)
            assert count==1, 'Review changed RGB pipeline declaration: '+name
    if args.check:
        for name, expected in files.items():
            assert (args.output/name).read_text() == expected, 'ROM differs: '+name
        assert updated_core==original_core, 'RGB pipeline coefficients differ from this model'
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        for name, body in files.items():
            (args.output/name).write_text(body, encoding='ascii')
        (args.output/'packed_manifest.json').write_text(json.dumps(description, indent=2)+'\n')
        if updated_core!=original_core:
            args.core.write_text(updated_core, encoding='ascii')
    print(('CHECK' if args.check else 'PACK')+' PASS: '+str(description['words'])+' exact 576-bit words')


if __name__ == '__main__':
    main()
