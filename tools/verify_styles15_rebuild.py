"""Compare rebuilt programming data with the accepted release, excluding metadata only."""
from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parents[1];rows={}
for kind in ['bit','hex']:
 new=R/'work/styles15/out'/('ArtFlow.'+kind)
 accepted=R/'releases/styles15_p1p2_20261025'/('ArtFlow_styles15_p1p2.'+kind)
 a=bytes.fromhex(new.read_text());b=bytes.fromhex(accepted.read_text())
 assert len(a)==len(b) and len(a)>256
 def metadata(data):
  fields={}
  for line in data[:256].decode('ascii').splitlines():
   if line:
    key,value=line.split(': ',1);assert key not in fields;fields[key]=value
  return fields
 x,y=metadata(a),metadata(b)
 for key in ['Generated','Project']:x.pop(key);y.pop(key)
 assert x==y,'Non-provenance header changed'
 assert a[256:]==b[256:],'Programming payload changed'
 rows[kind]=dict(decoded_bytes=len(a),header_bytes=256,changed_header_fields=['Generated','Project'],payload_identical=True,payload_sha256=hashlib.sha256(a[256:]).hexdigest(),rebuilt_file_sha256=hashlib.sha256(new.read_bytes()).hexdigest(),accepted_file_sha256=hashlib.sha256(accepted.read_bytes()).hexdigest())
result=dict(status='PASS',scope='Only Generated/Project metadata and resulting header padding differ; complete decoded bytes after offset 256 match.',artifacts=rows)
(R/'reports/styles15_payload_equivalence.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
