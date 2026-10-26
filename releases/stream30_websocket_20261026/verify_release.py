from pathlib import Path
import argparse,json,hashlib
p=argparse.ArgumentParser(description='Offline hashes only; never opens hardware');p.parse_args()
r=Path(__file__).resolve().parent
m=json.loads((r/'manifest.json').read_text(encoding='utf-8-sig'))
for n,v in m['files'].items():
 f=r/n
 assert f.stat().st_size==v['bytes'] and hashlib.sha256(f.read_bytes()).hexdigest()==v['sha256'],n
print('PASS',len(m['files']),'public files; private payload excluded')
