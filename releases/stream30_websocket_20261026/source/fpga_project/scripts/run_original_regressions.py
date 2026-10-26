from pathlib import Path
import sys,json,hashlib
R=Path(__file__).resolve().parents[1];F=R/'fpga';sys.path.insert(0,str(F/'tools'));import build_styles15 as b
from check_round23t_project import verify,W
W.mkdir(parents=True,exist_ok=True);(F/'reports').mkdir(exist_ok=True)
b.run('tools/build_firmware.py');verify();b.run('tools/test_firmware.py');b.run('tools/verify_package.py','--record');b.run('tools/regenerate_package.py')
rows=[];hashes={}
for name,cmd in json.loads((F/'tools/styles15_tests.json').read_text()).items():
 out='styles15_v2_'+name;b.run('tools/run_styles15_case.py',cmd[0],out,*cmd[1:]);p=F/'work'/out/'summary.json';d=json.loads(p.read_text());assert d['status']=='PASS'
 for n,h in d['source_sha256'].items():assert hashlib.sha256((F/n).read_bytes()).hexdigest()==h,n
 for q in [p,p.parent/'simulation.log']:hashes[q.relative_to(F).as_posix()]=hashlib.sha256(q.read_bytes()).hexdigest()
 hashes.update(d['source_sha256']);rows.append({'name':name,'status':'PASS','evidence':d['evidence']})
(F/'reports/round23t_functional_receipt.json').write_text(json.dumps({'status':'PASS','tests':rows,'implementation':verify(),'sha256':hashes,'scope':'Eight fresh original RTL regressions plus four native firmware groups. Vendor simulation source paths retained as absolute paths. No hardware test.'},indent=2));print('ORIGINAL_REGRESSIONS_PASS')
