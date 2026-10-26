from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parents[1]
receipts=['logs/rtl/summary.json','logs/tap/summary.json','logs/reset-equivalence/summary.json','logs/host-tests.json','logs/browser-tests.json']
counts={}
for n in receipts:
 d=json.loads((R/n).read_text());assert d['status']=='PASS',n
 for name,h in d['source_sha256'].items():
  p=Path(name);p=p if p.is_absolute() else R/p
  assert hashlib.sha256(p.read_bytes()).hexdigest()==h,(n,str(p))
 counts[n]=len(d['source_sha256'])
(R/'logs/current-regression-binding.json').write_text(json.dumps({'status':'PASS','receipt_source_counts':counts,'hardware_tested':False},indent=2))
print('PASS: current RTL, tap, reset, C and actual browser sources match tested hashes',counts)
