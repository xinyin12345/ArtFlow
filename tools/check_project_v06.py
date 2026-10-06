"""v06 build gate: local sources, firmware, font, board pins and preserved v05."""
from pathlib import Path
import argparse,json,xml.etree.ElementTree as ET
from check_project_v05 import sha,implementation_sources,check_firmware,check_pins
from gen_osd_font import generate
ROOT=Path(__file__).resolve().parents[1]
def check_baseline(required=False):
    baseline=ROOT.parent/'v05'
    if not baseline.is_dir():
        if required:raise ValueError('Original v05 required to certify baseline preservation')
        return None
    files=json.loads((ROOT/'doc/baseline_v05/source_sha256.json').read_text())
    for name,digest in files.items():
        if sha(baseline/name)!=digest:raise ValueError('v05 changed: '+name)
    return len(files)
def check():
    sources=implementation_sources();check_pins();check_firmware()
    for name in ('artflow_button','artflow_fps','artflow_ui','artflow_osd'):
        if 'rtl/video/'+name+'.v' not in sources:raise ValueError('Missing v06 RTL '+name)
    if (ROOT/'rtl/video/osd_font.mem').read_text()!=generate():raise ValueError('Font differs from generator')
    ns={'p':'http://www.efinixinc.com/peri_design_db'}
    pins={n.attrib['name']:n.attrib for n in ET.parse(ROOT/'ArtFlow.peri.xml').findall('.//p:comp_gpio',ns)}
    for name,pin in [('key_mode_n','GPIOR_22'),('key_osd_n','GPIOR_21'),('i_arstn','GPIOL_07')]:
        if pins[name]['gpio_def']!=pin or pins[name]['mode']!='input' or pins[name]['io_standard']!='3.3 V LVCMOS':
            raise ValueError('Incorrect button pin '+name)
    return sources,check_baseline()
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--snapshot',action='store_true');p.add_argument('--check-snapshot',action='store_true');a=p.parse_args()
    sources,count=check();snapshot=ROOT/'work/implementation_source_sha256.json'
    if a.snapshot:snapshot.parent.mkdir(parents=True,exist_ok=True);snapshot.write_text(json.dumps(sources,indent=2)+'\n')
    if a.check_snapshot and json.loads(snapshot.read_text())!=sources:raise ValueError('Stale implementation')
    print(f'V06 PROJECT PASS: {len(sources)} inputs; original v05 files unchanged: {count}')
if __name__=='__main__':main()
