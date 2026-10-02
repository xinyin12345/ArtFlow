"""Read the actual top-level literal configuration; reject ambiguity/expressions.

ArtFlow_top.v remains the single user-editable board configuration. Comments are
removed before parsing, and unsupported syntax fails rather than using defaults.
"""
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]
TOP = ROOT / 'rtl/ArtFlow_top.v'
NAMES = ('MAX_HRES MAX_VRES HFP HSP HBP VFP VSP VBP CFG_R_GAIN CFG_G_GAIN '
         'CFG_B_GAIN CFG_BAYER CFG_PIX_REV').split()


def load_config(path=TOP):
    raw = Path(path).read_bytes()
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', raw.decode('utf-8'), flags=re.S)
    config = {}
    for name in NAMES:
        matches = re.findall(r'\blocalparam\s+(?:\[[^]]+\]\s*)?' + name + r'\s*=\s*([^;]+);', source)
        if len(matches) != 1:
            raise ValueError(f'{name}: expected exactly one literal declaration')
        value = matches[0].strip().replace('_', '')
        if re.fullmatch(r'\d+', value):
            config[name] = int(value)
        else:
            m = re.fullmatch(r"(\d+)'([hHdDbB])([0-9a-fA-F]+)", value)
            if not m:
                raise ValueError(f'{name}: unsupported constant {value!r}; no fallback allowed')
            bits, radix, digits = m.groups()
            n = int(digits, {'h': 16, 'd': 10, 'b': 2}[radix.lower()])
            if n >= 2 ** int(bits):
                raise ValueError(f'{name}: literal overflow')
            config[name] = n
    if config['MAX_HRES'] < 4 or config['MAX_VRES'] < 2 or config['MAX_HRES'] % 4 or config['MAX_VRES'] % 2:
        raise ValueError('RAW width must be divisible by 4 and height by 2')
    if any(config[k] % 2 for k in ('HFP', 'HSP', 'HBP')):
        raise ValueError('Horizontal timing must be divisible by 2')
    if (config['HSP'] == 0 or config['VSP'] == 0 or
        sum(config[k] for k in ('MAX_HRES','HFP','HSP','HBP')) // 2 > 8191 or
        sum(config[k] for k in ('MAX_VRES','VFP','VSP','VBP')) > 8191):
        raise ValueError('Invalid output timing')
    if config['CFG_BAYER'] > 3 or config['CFG_PIX_REV'] > 1:
        raise ValueError('Invalid Bayer/pixel-order configuration')
    if any(not 0 <= config[k] <= 65535 for k in ('CFG_R_GAIN','CFG_G_GAIN','CFG_B_GAIN')):
        raise ValueError('Gain out of range')
    config['top_sha256'] = hashlib.sha256(raw).hexdigest()
    return config


def gains(config):
    return dict(zip(('r','g','b'), (config[f'CFG_{k}_GAIN'] for k in ('R','G','B'))))
