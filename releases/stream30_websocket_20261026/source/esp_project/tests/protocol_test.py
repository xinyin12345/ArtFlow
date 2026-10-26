from pathlib import Path
import struct,zlib,subprocess,json
R=Path(__file__).resolve().parents[1];O=R/'logs/protocol';O.mkdir(exist_ok=True)
def packet(t,seq=7,off=0,p=b'',session=0x12345678):
 h=struct.pack('<4sBBBBIIIHHHH',b'AFS1',1,t,0,0,session,seq,off,len(p),160,90,0)
 raw=h+p+bytes(1024-len(p));return raw+struct.pack('<I',zlib.crc32(raw))
image=bytes((i*37+i//320)&255 for i in range(28800))
valid=[packet(1)]+[packet(2,off=o,p=image[o:o+1024]) for o in range(0,len(image),1024)]+[packet(3,off=28800,p=struct.pack('<I',zlib.crc32(image)))]
cases={'valid':valid,'bad_crc':valid[:2]+[valid[2][:100]+bytes([valid[2][100]^1])+valid[2][101:]]+valid[3:],'lost_chunk':valid[:2]+valid[3:],'reordered':valid[:2]+[valid[3],valid[2]]+valid[4:],'cancel':valid[:3]+[packet(4)]+valid[3:],'sender_reset':valid[:5]+[packet(1,seq=8)]+valid[5:],'stale_session':[packet(1,session=0xabcdef00)]+valid[1:],'wrong_frame_crc':valid[:-1]+[packet(3,off=28800,p=bytes(4))],'truncated_frame':valid[:-1],'recovery_after_error':valid[:3]+[packet(2,off=4096,p=image[4096:5120])]+valid,'diagnostic':[packet(5,p=bytes(range(16)))], 'duplicate_chunk':valid[:2]+[valid[1]]+valid[2:]}
exe=O/'receiver.exe';gcc='C:/msys64/ucrt64/bin/gcc.exe'
subprocess.run([gcc,'-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(R/'protocol'),str(R/'protocol/afs.c'),str(R/'tests/protocol_runner.c'),'-o',str(exe)],check=True)
report={}
for name,packets in cases.items():
 f=O/(name+'.spi');f.write_bytes(b''.join(packets));want=1 if name in ['valid','recovery_after_error'] else 0
 r=subprocess.run([str(exe),str(f),str(O/(name+'.ws')),str(want)],capture_output=True,text=True,check=True);report[name]=r.stdout.strip()
assert zlib.crc32(b'123456789')==0xcbf43926
(O/'image.bin').write_bytes(image);(O/'status.hex').write_text('')
status=bytearray(packet(128));status[6]=1;status[7]=1;status[-4:]=struct.pack('<I',zlib.crc32(status[:-4]));(O/'status.hex').write_text('\n'.join(f'{b:02x}' for b in status))
(O/'summary.json').write_text(json.dumps({'status':'PASS','cases':report,'hardware_tested':False},indent=2));print(json.dumps(report,indent=2))
