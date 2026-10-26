from pathlib import Path
import struct,json,zlib
R=Path(__file__).resolve().parents[1];p=R/'logs/protocol/rtl.ws';b=p.read_bytes();assert len(b)==2*28832
image=b''.join(struct.pack('<H',((a>>3)<<11)|((y>>2)<<5)|((a^y)>>3)) for y in range(90) for a in range(160))
for i,epoch in enumerate([7,10]):
 f=b[i*28832:(i+1)*28832];assert f[28:-4]==image;assert struct.unpack_from('<I',f,12)[0]==epoch;assert zlib.crc32(f[:-4])==struct.unpack_from('<I',f,len(f)-4)[0]
d={'status':'PASS','complete_frames':2,'pixels_checked':28800,'source_epochs':[7,10],'scope':'RTL wire -> actual C receiver -> exact source RGB565 and WebSocket CRC'}
(R/'logs/protocol/rtl_crosscheck.json').write_text(json.dumps(d,indent=2));print(json.dumps(d))
