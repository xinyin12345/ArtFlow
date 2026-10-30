from pathlib import Path
import json,hashlib,zlib,struct
from datetime import datetime,timezone
R=Path(__file__).resolve().parents[1]
KEEP=[0,16,17,1,11,13,2,5]
sha=lambda x:hashlib.sha256(x).hexdigest()
def verify(data,original,manifest):
 assert manifest['confirmed_order']==[0,5,1,3,2,14,7,8]
 assert manifest['flash_base']==0x400000 and manifest['slot_bytes']==16384
 assert manifest['source19_order']==KEEP
 assert len(data)==131072 and manifest['archive_bytes']==len(data)
 assert sha(data)==manifest['sha256']
 assert len(manifest['models'])==8 and manifest['flash_end_inclusive']==0x41ffff
 for new,old in enumerate(KEEP):
  s=data[new*16384:(new+1)*16384];o=original[old*16384:(old+1)*16384];x=manifest['models'][new]
  assert x['previous15_id']==[0,5,1,3,2,14,7,8][new]
  assert x['name']==['glass','sketch','oil','starry','halftone','sand','inkwash','woodrich'][new]
  assert x['id']==new and x['old_id']==old and x['slot_offset']==new*16384 and x['flash_address']==0x400000+new*16384
  assert int.from_bytes(s[:4],'little')==0x4d534641 and int.from_bytes(s[4:8],'little')==1
  assert int.from_bytes(s[8:12],'little')==new and int.from_bytes(s[12:16],'little')==14448
  assert s[:8]==o[:8] and s[12:]==o[12:],'Only AFSM ID may change'
  assert int.from_bytes(s[16:20],'little')==zlib.crc32(s[32:14480])==int(x['crc32'],16)
  assert s[20:32]==bytes(12) and s[14480:]==b'\xff'*1904
  assert sha(s[32:14480])==x['payload_sha256'] and sha(s)==x['slot_sha256']
 assert data[:16384]==original[:16384] and manifest['models'][0]['name']=='glass'
 return True
if __name__=='__main__':
 data=(R/'network/styles8/models8_parameters.bin').read_bytes();original=(R/'network/styles15/source19_parameters.bin').read_bytes();m=json.loads((R/'network/styles8/models8_manifest.json').read_text(encoding='utf-8'));verify(data,original,m)
 results=[]
 for label,offset in [('header_id',8),('header_crc',16),('payload',40),('padding',15000)]:
  damaged=bytearray(data);damaged[offset]^=1
  mm=dict(m,sha256=sha(damaged))
  try:verify(damaged,original,mm)
  except AssertionError:results.append(label+':REJECTED')
  else:raise AssertionError('Corruption accepted: '+label)
 for label,damaged in [('truncated',data[:-1]),('reordered',data[16384:32768]+data[:16384]+data[32768:])]:
  mm=dict(m,sha256=sha(damaged))
  try:verify(damaged,original,mm)
  except AssertionError:results.append(label+':REJECTED')
  else:raise AssertionError('Corruption accepted: '+label)
 result=dict(status='PASS',utc=datetime.now(timezone.utc).isoformat(),retained_old_ids=KEEP,new_ids=list(range(8)),bytes=len(data),sha256=sha(data),all8_headers_crc_payload_padding_slots=True,glass_slot_byte_identical=True,corruption_checks=results,hardware_read_or_write=False)
 print(json.dumps(result,ensure_ascii=False,indent=2))
 import sys
 if '--record' in sys.argv:(R/'reports/styles8/verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
