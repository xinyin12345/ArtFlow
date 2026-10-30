"""Offline verification only. Standard Python 3; no EDA or hardware access."""
from pathlib import Path
import hashlib,json,struct,zlib,sys
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
for n,v in m['files'].items():
 p=root/n
 assert p.resolve().is_relative_to(root) and p.stat().st_size==v['bytes'] and sha(p)==v['sha256'],n
for line in (root/'SHA256SUMS.txt').read_text().splitlines():
 h,n=line.split('  ',1);assert sha(root/n)==h,n
config=bytes.fromhex((root/'fpga/ArtFlow_osd_blackbars_20261030.hex').read_text())
model=(root/'models/models8_parameters.bin').read_bytes();meta=json.loads((root/'models/models8_manifest.json').read_text(encoding='utf-8'))
assert bytes.fromhex((root/'models/models8_parameters.hex').read_text())==model
assert len(model)==0x20000 and hashlib.sha256(model).hexdigest()==meta['sha256']
assert [x['name'] for x in meta['models']]==['glass','sketch','oil','starry','halftone','sand','inkwash','woodrich']
for i,x in enumerate(meta['models']):
 s=model[i*16384:(i+1)*16384];h=struct.unpack_from('<8I',s)
 assert h[:4]==(0x4d534641,1,i,14448) and h[4]==zlib.crc32(s[32:14480])==int(x['crc32'],16)
 assert h[5:]==(0,0,0) and s[14480:]==b'\xff'*1904
 assert hashlib.sha256(s).hexdigest()==x['slot_sha256'] and hashlib.sha256(s[32:14480]).hexdigest()==x['payload_sha256']
 assert x['flash_address']==0x400000+i*16384
actual=bytes.fromhex((root/'flash/ArtFlow_osd_8styles_fullflash.hex').read_text())
assert 0<len(config)<0x400000 and len(actual)==0x420000
assert actual==config+b'\xff'*(0x400000-len(config))+model
print('PASS: all file SHA256; eight model IDs/CRC/payload/padding; configuration/FF gap/models byte-exact; 0x000000..0x41FFFF. No hardware access.')
