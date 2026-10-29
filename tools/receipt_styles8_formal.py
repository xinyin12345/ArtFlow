"""Bind current eight-test outcomes to their source and generated dump hashes."""
from pathlib import Path
import hashlib,json,datetime
from check_round23t_project import verify
R=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
commands=json.loads((R/'tools/styles8_tests.json').read_text());rows=[];files=[]
for name in commands:
 p=R/'work'/('styles8_v2_'+name)/'summary.json';d=json.loads(p.read_text());assert d['status']=='PASS',name
 for n,h in (d['source_sha256']|d.get('vector_sha256',{})).items():assert sha(R/n)==h,('Stale test source',name,n)
 log=p.parent/'simulation.log';assert '# Errors: 0, Warnings: 0' in log.read_text(),('Unreviewed simulator warnings/errors',name)
 rows.append(dict(name=name,status='PASS',evidence=d['evidence']));files.extend([p,log]);files.extend(R/n for n in (d['source_sha256']|d.get('vector_sha256',{})))
for name in ['system_input.hex','system_output.hex']:
 p=R/'work/styles8_v2_system'/name;assert p.stat().st_size>0;files.append(p)
for name in ['outputs/firmware/host_tests.json','outputs/firmware/build_manifest.json','reports/styles8/verification.json','tools/styles8_tests.json']:files.append(R/name)
result=dict(status='PASS',utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),tests=rows,implementation=verify(),sha256={p.relative_to(R).as_posix() if p.is_relative_to(R) else p.as_posix():sha(p) for p in set(files)},scope='Fresh formal-path eight RTL regressions and four firmware host-test groups. System CNN is a transaction fixture; no new full CNN arithmetic/CPU boot simulation or hardware validation.')
(R/'reports/styles8/round23t_functional_receipt.json').write_text(json.dumps(result,indent=2)+'\n')
print('FORMAL_FUNCTIONAL_GATE_PASS',len(rows),'tests')
