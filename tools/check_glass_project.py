"""Source, model and firmware evidence for the glass trial project."""
from pathlib import Path
import hashlib,json,sys,xml.etree.ElementTree as ET
from check_project_v05 import check_firmware,check_pins
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def implementation_sources():
    bundle=R/'network/glass_5_20epochs_sum8192_480x270_input3x3_res32_r4_int8'
    for name,digest in json.loads((bundle/'SHA256.json').read_text()).items():
        assert sha(bundle/name)==digest,'Original model bundle changed: '+name
    ns={'e':'http://www.efinixinc.com/enf_proj'}
    tree=ET.parse(R/'ArtFlow_glass.xml')
    names=[n.attrib['name'] for n in tree.findall('.//e:design_file',ns)]
    assert 'rtl/cnn/glass_int8/glass_int8.v' in names and 'rtl/accel/artflow_glass_dma.v' in names
    assert 'rtl/cnn/student_u8/student_u8_flat.v' not in names
    names+=['ArtFlow_glass.xml','ArtFlow.sdc','ArtFlow.peri.xml']
    names += [p.relative_to(R).as_posix() for p in (R/'rtl').rglob('*.mem')]
    names += [p.relative_to(R).as_posix() for p in (R/'rtl/cnn/glass_int8').glob('*.vh')]
    names += [p.relative_to(R).as_posix() for p in (R/'ip/sapphire_soc').glob('*.bin')]
    names += [p.relative_to(R).as_posix() for p in (R/'network/glass_5_20epochs_sum8192_480x270_input3x3_res32_r4_int8').rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    return {n:sha(R/n) for n in sorted(set(names))}
if __name__=='__main__':
    check_firmware();check_pins();s=implementation_sources()
    snap=R/'work/glass_int8/implementation_source_sha256.json'
    if '--snapshot' in sys.argv:snap.write_text(json.dumps(s,indent=2))
    if '--check-snapshot' in sys.argv:assert json.loads(snap.read_text())==s,'Source changed during implementation'
    print('GLASS PROJECT PASS',len(s),'pinned inputs')

