from pathlib import Path
import json,struct,zlib,hashlib
R=Path(__file__).resolve().parents[1]
ORDER=[0,17,11,1,3,16,8,2,5,15,6,7,10,4,13]
def regenerate():
 source=(R/'network/styles15/source19_parameters.bin').read_bytes();assert hashlib.sha256(source).hexdigest()=='dfc558d7bc3be10b7a78c8e68e71108e6d453f6af454425192afe29538d0f856'
 result=bytearray()
 for new,old in enumerate(ORDER):
  slot=bytearray(source[old*16384:(old+1)*16384]);h=struct.unpack_from('<8I',slot);assert h[:4]==(0x4d534641,1,old,14448) and h[4]==zlib.crc32(slot[32:14480]);struct.pack_into('<I',slot,8,new);result.extend(slot)
 return bytes(result)
if __name__=='__main__':
 data=regenerate();assert data==(R/'network/styles15/models15_parameters.bin').read_bytes();assert bytes.fromhex((R/'network/styles15/models15_parameters.hex').read_text())==data
 print('CONFIRMED_ORDER_REGENERATION_PASS',len(data),hashlib.sha256(data).hexdigest())
