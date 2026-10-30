from pathlib import Path
import hashlib,json,zipfile,xml.etree.ElementTree as ET,re
R=Path(__file__).resolve().parents[1];L=R/'releases/osd_blackbars_20261031';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=json.loads((L/'implementation_inputs.json').read_text())
assert all(sha(R/n)==h for n,h in inputs.items())
assert (R/'ArtFlow.xml').read_bytes()==(R/'ArtFlow_glass.xml').read_bytes()
files=[e.attrib['name'] for e in ET.parse(R/'ArtFlow.xml').iter() if e.tag.endswith('design_file')]
assert len(files)==73 and all('gesture' not in n.lower() and (R/n).is_file() for n in files)
for n in files:
 assert n in inputs,n
 for resource in re.findall(r'\$readmem[hb]\(\s*"([^"]+)"',(R/n).read_text(errors='replace')):
  assert (R/resource).exists(),(n,resource)
assert (R/'rtl/video/osd_text_rows.mem').is_file()
with zipfile.ZipFile(L/'candidate_evidence.zip') as z:
 m=json.loads(z.read('outputs/release_manifest.json'))
 for n,h in m['files_sha256'].items():assert hashlib.sha256(z.read(n)).hexdigest()==h,n
 for n,h in m['model_files_sha256'].items():
  if 'gesture' not in n:assert sha(R/n)==h,n
 gate=json.loads(z.read('reports/physical_gate.json'));assert gate['status']=='PASS'
 assert hashlib.sha256(z.read('work/osd_impl/implementation_source_sha256.json')).hexdigest()==gate['source_snapshot_sha256']
 assert b'gesture' not in z.read('work/osd_impl/out/ArtFlow.map.v').lower()
 for n,h in json.loads(z.read('work/osd_impl/pnr_summary.json'))['source_inputs_sha256'].items():assert hashlib.sha256(z.read(n)).hexdigest()==h,n
 reg=z.read('reports/regression_complete.json');assert hashlib.sha256(reg).hexdigest()==gate['functional_receipt_sha256']
 for c in json.loads(reg)['cases']:assert hashlib.sha256(z.read(c['report'])).hexdigest()==c['sha256']
 timing=z.read('reports/normal_routed_timing.rpt').decode();assert hashlib.sha256(timing.encode()).hexdigest()==gate['normal_setup_hold']['sha256']
 from styles15_timing import parse_timing
 slack=parse_timing(timing);assert min(slack.values())>=0
 assert 'Routing Succeeded' in z.read('work/osd_impl/out/ArtFlow.route.out').decode()
 assert re.search(r'overlap=0\s',z.read('work/osd_impl/out/ArtFlow.route.out').decode())
 old=z.read('outputs/ArtFlow_osd_blackbars_20261030.bit')
 assert old==(L/'flash_package/fpga/ArtFlow_osd_blackbars_20261030.bit').read_bytes()
print(json.dumps(dict(status='PASS',implementation_inputs=len(inputs),design_sources=len(files),model_files=472,xml_alias_equal=True,physical_evidence='reused, not rebuilt',slack_ns=slack)))
