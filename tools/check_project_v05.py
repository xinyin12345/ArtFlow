"""Fail closed on missing sources, conflicting pins, or stale BRAM firmware."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def implementation_sources():
    ns = {'e': 'http://www.efinixinc.com/enf_proj'}
    project = ET.parse(ROOT/'ArtFlow.xml')
    names = [n.attrib['name'] for n in project.findall('.//e:design_file', ns)]
    assert len(names) == len(set(names)), 'Duplicate design source'
    assert not any(n.startswith('rtl/cam_i2c_ctrl/') for n in names), 'Legacy I2C master still in active design'
    for name in ['rtl/control/artflow_soc.v', 'rtl/control/artflow_control.v',
                 'rtl/control/artflow_camera_gate.v', 'ip/sapphire_soc/sapphire_soc.v']:
        assert name in names, 'Missing v05 source: '+name
    names += ['ArtFlow.xml', 'ArtFlow.peri.xml', 'ArtFlow.sdc']
    names += [p.relative_to(ROOT).as_posix() for p in (ROOT/'ip/sapphire_soc').glob('*.bin')]
    names += [p.relative_to(ROOT).as_posix() for p in (ROOT/'rtl').rglob('*.mem')]
    for name in names:
        path=(ROOT/name).resolve()
        assert path.is_relative_to(ROOT.resolve()) and path.is_file(), 'Nonlocal/missing source: '+name
    return {name:sha(ROOT/name) for name in sorted(set(names))}


def check_baseline(required=False):
    if not (ROOT.parent/'v04').is_dir():
        if required: raise ValueError('Packaging requires the original v04 baseline beside v05')
        return None
    baseline=json.loads((ROOT/'doc/baseline_v04/source_sha256.json').read_text())
    for name,digest in baseline.items():
        assert sha(ROOT.parent/'v04'/name)==digest, 'v04 baseline changed: '+name
    return len(baseline)


def check_firmware():
    meta=json.loads((ROOT/'outputs/firmware/build_manifest.json').read_text())
    for name,digest in meta['source_hashes'].items():
        assert sha(ROOT/name)==digest, 'Firmware source changed since build: '+name
    assert sha(ROOT/'rtl/cam_i2c_ctrl/i2c/i2c_master_reg_rom.v')==meta['camera_rom_sha256']
    assert sha(ROOT/'outputs/firmware/artflow_v05.bin')==meta['binary_sha256']
    assert sha(ROOT/'outputs/firmware/artflow_v05.elf')==meta['elf_sha256']
    recovered=bytearray(8192)
    assert len(meta['lanes'])==4
    for lane,item in enumerate(meta['lanes']):
        path=ROOT/item['path']
        assert sha(path)==item['sha256'], 'Stale BRAM lane: '+str(lane)
        words=path.read_text().splitlines()
        assert len(words)==2048 and all(re.fullmatch('[01]{8}',w) for w in words)
        recovered[lane::4]=bytes(int(w,2) for w in words)
    binary=(ROOT/'outputs/firmware/artflow_v05.bin').read_bytes()
    assert recovered==binary.ljust(8192,b'\0'), 'BRAM bytes do not match executable image'
    return meta['image_bytes']


def check_pins():
    ns={'e':'http://www.efinixinc.com/peri_design_db'}
    nodes=ET.parse(ROOT/'ArtFlow.peri.xml').findall('.//e:comp_gpio',ns)
    pins=[n.attrib['gpio_def'] for n in nodes]
    assert len(pins)==len(set(pins)), 'Duplicate GPIO location'
    by_name={n.attrib['name']:n for n in nodes}
    for name,pin in [('uart_rx','GPIOL_02'),('uart_tx','GPIOR_28')]:
        assert by_name[name].attrib['gpio_def']==pin
        assert by_name[name].attrib['io_standard']=='3.3 V LVCMOS'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot', action='store_true')
    parser.add_argument('--check-snapshot', action='store_true')
    args=parser.parse_args()
    source=implementation_sources()
    check_pins()
    image_size=check_firmware()
    count=check_baseline()
    snapshot=ROOT/'work/implementation_source_sha256.json'
    if args.snapshot:
        snapshot.write_text(json.dumps(source,indent=2)+'\n')
    if args.check_snapshot:
        assert json.loads(snapshot.read_text())==source, 'Implementation inputs changed during/after build'
    baseline_message=f'{count} v04 sources unchanged' if count is not None else 'portable build; original v04 comparison unavailable'
    print(f'PROJECT PASS: {len(source)} implementation inputs; {image_size}-byte firmware; {baseline_message}')


if __name__=='__main__':
    main()
