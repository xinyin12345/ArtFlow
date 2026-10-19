from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parent
m=json.loads((r/'PACKAGE_SHA256.json').read_text(encoding='utf8'))
for n,h in m.items():
    p=r/n
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=h:
        raise SystemExit('FAIL: '+n)
for report in ['map_20261013_213033','pnr_20261013_213229']:
    if (r/'student_u8_flat.v').read_bytes()!=(r/'reports'/report/'student_u8_flat.v').read_bytes():
        raise SystemExit('FAIL: RTL report snapshot')
    for n in ['shared_weights.mem','shared_bias.mem','shared_main.mem','shared_beta.mem']:
        if (r/'mem'/n).read_bytes()!=(r/'reports'/report/'mem'/n).read_bytes():
            raise SystemExit('FAIL: ROM report snapshot '+n)
print('PASS:',len(m),'file hashes; RTL/ROM match synthesis and PNR snapshots')
