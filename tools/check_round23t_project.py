from pathlib import Path
import json,hashlib,xml.etree.ElementTree as ET
R=Path(__file__).resolve().parents[1];W=R/'work/styles15';SNAP=W/'implementation_source_sha256.json'
def verify(tests=True):
 expected=json.loads((R/'doc/styles15/source_manifest.json').read_text())
 current={n:hashlib.sha256((R/n).read_bytes()).hexdigest() for n in expected}
 assert current==expected,'Reviewed implementation/source files changed'
 assert (R/'ArtFlow.xml').read_bytes()==(R/'ArtFlow_glass.xml').read_bytes(),'Entrypoints differ'
 root=ET.parse(R/'ArtFlow.xml').getroot()
 for e in root.iter():
  if e.tag.endswith('design_file'):assert (R/e.attrib['name']).is_file(),e.attrib
 params={e.attrib['name']:e.attrib.get('value') for e in root.iter() if e.tag.endswith('param')}
 assert params['optimization_level']=='TIMING_3' and params['spi_low_power_mode']=='off'
 return current
if __name__=='__main__':print('FORMAL_STYLES15_SOURCE_GATE_PASS',len(verify()))
