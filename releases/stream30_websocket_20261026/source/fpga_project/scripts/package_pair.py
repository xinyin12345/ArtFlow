from pathlib import Path
import json,hashlib,zipfile,datetime
R=Path(__file__).resolve().parents[1];F=R/'fpga'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8'))
assert load(R/'logs/fpga-final.json')['status'].startswith('PASS')
assert load(R/'logs/cdc-audit-parser-tests.json')['status']=='PASS'
assert load(R/'logs/current-regression-binding.json')['status']=='PASS'
files=set()
def add(p):
 if p.is_file() and '__pycache__' not in p.parts:files.add(p)
def tree(p):
 for q in p.rglob('*'):add(q)
for n in ['README.md','DELIVERY_REPORT.md','PROGRESS.json','BuildFPGA.ps1','esp-stream-compatible-local.zip']:add(R/n)
for n in ['docs','protocol','scripts','tests','dist']:tree(R/n)
for n in ['rtl','firmware','ip','network','sim','tools','doc','candidates']:tree(F/n)
for p in F.iterdir():add(p)
for p in (F/'reports').glob('*.json'):add(p)
for p in (R/'esp32').iterdir():add(p)
for n in ['main','bootloader_components']:tree(R/'esp32'/n)
for p in (R/'logs').rglob('*'):
 if p.suffix in ['.json','.log','.txt','.spi','.ws','.bin','.hex'] and 'work' not in p.relative_to(R/'logs').parts:add(p)
# Keep original regression receipts and simulator transcripts, not simulator databases.
for p in (F/'work').glob('styles15_v2_*'):
 for n in ['summary.json','simulation.log']:add(p/n)
for p in (F/'work/styles15').glob('*.json'):add(p)
for p in (F/'work/styles15').glob('*.log'):add(p)
tree(F/'work/styles15/audit_attempt01_missing_epoch_alias')
for n in load(F/'doc/styles15/source_manifest.json'):
 assert F/n in files,n
for manifest in [R/'dist/esp32/manifest.json',R/'dist/fpga/manifest.json']:
 for n,e in load(manifest)['files'].items():assert sha(manifest.parent/n)==e['sha256'],n
# Do not include an older self-referential package report when repackaging.
files={p for p in files if p.name not in ['paired-package.json','paired-package-files.json']}
entries={p.relative_to(R).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(files)}
manifest={'format':1,'status':'OFFLINE_PAIRED_CANDIDATE','contains_local_credentials':True,'hardware_stream_verified':False,'files':entries}
z=R/'wifi-stream-paired-local.zip'
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as f:
 for p in sorted(files):f.write(p,p.relative_to(R).as_posix())
 f.writestr('PACKAGE_MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(z) as f:
 assert f.testzip() is None
 assert set(f.namelist())==set(entries)|{'PACKAGE_MANIFEST.json'}
 for n,e in entries.items():assert hashlib.sha256(f.read(n)).hexdigest()==e['sha256'],n
result={'status':'PASS_ARCHIVE_INTEGRITY','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'path':str(z),'bytes':z.stat().st_size,'sha256':sha(z),'files':len(entries)+1,'contains_local_credentials':True,'hardware_stream_verified':False}
(R/'logs/paired-package.json').write_text(json.dumps(result,indent=2));(R/'logs/paired-package-files.json').write_text(json.dumps(entries,indent=2));print(json.dumps(result,indent=2))
