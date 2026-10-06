"""Protect the single source of board parameters against silent parser fallback."""
import tempfile
from pathlib import Path
from v04_config import ROOT, NAMES, load_config, gains
from v04_golden import bin2x2
from run_v04 import config_params, plan


def main():
    base = load_config()
    source = '\n'.join(f'localparam {k} = {base[k]};' for k in NAMES)
    (ROOT/'work').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='config_', dir=ROOT/'work') as scratch:
        path = Path(scratch) / 'top.v'
        def read(text):
            path.write_text(text, encoding='utf-8')
            return load_config(path)
        def reject(text):
            try:
                read(text)
            except ValueError:
                return
            raise AssertionError('Malformed configuration accepted')
        gain_decl = f'CFG_G_GAIN = {base["CFG_G_GAIN"]}'
        changed = source.replace(gain_decl, "CFG_G_GAIN = 16'd128")
        cfg = read(changed)
        assert cfg['CFG_G_GAIN'] == 128 and cfg['top_sha256'] != base['top_sha256']
        assert config_params(cfg)['GAIN_G'] == 128
        assert all(p['GAIN_G'] == 128 for _, top, p, _ in plan(cfg, full=True)
                   if top in ('tb_bayer_bin2x2', 'tb_v04_checked'))
        assert bin2x2([[512,512],[512,512]], 0, gains(cfg))[0][0][1] == 64
        assert read(source + '\n// localparam CFG_G_GAIN = 0;\n/* localparam CFG_G_GAIN = 1; */')['CFG_G_GAIN'] == base['CFG_G_GAIN']
        reject(source + '\nlocalparam CFG_G_GAIN = 0;')
        reject(source.replace('CFG_G_GAIN', 'REMOVED_GAIN'))
        reject(source.replace(gain_decl, 'CFG_G_GAIN = (128 + 127)'))
        reject(source.replace(gain_decl, "CFG_G_GAIN = 8'd256"))
        reject(source.replace(f'MAX_HRES = {base["MAX_HRES"]}', 'MAX_HRES = 0'))
        reject(source.replace(f'MAX_HRES = {base["MAX_HRES"]}', 'MAX_HRES = 1919'))
        reject(source.replace(f'CFG_DUAL_WINDOW = {base["CFG_DUAL_WINDOW"]}', 'CFG_DUAL_WINDOW = 2'))
        reject(source.replace(f'MAX_HRES = {base["MAX_HRES"]}', 'MAX_HRES = 1916'))
        reject(source.replace(f'MAX_HRES = {base["MAX_HRES"]}', 'MAX_HRES = 8192'))
        legacy=read(source.replace(f'CFG_DUAL_WINDOW = {base["CFG_DUAL_WINDOW"]}', 'CFG_DUAL_WINDOW = 0'))
        assert config_params(legacy)['DUAL_WINDOW'] == 0
    print('config: PASS (gain propagation, comments, duplicate/missing/expression/overflow/geometry)')


if __name__ == '__main__':
    main()
