from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parents[1];W=R/'work/osd_impl';SNAP=W/'implementation_source_sha256.json'
def verify():
 expected=json.loads(SNAP.read_text());actual={f:hashlib.sha256((R/f).read_bytes()).hexdigest() for f in expected}
 assert actual==expected, 'OSD implementation source changed after snapshot'
 return actual
