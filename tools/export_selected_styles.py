"""Reproduce the read-only Flash archive from pinned selected integer models.

Never trains, edits a checkpoint, or programs hardware. Default output is work/.
The source manifest pins the exact user-selected model, NPZ, graph and proof.
"""
from pathlib import Path
import argparse,json,hashlib,struct,zlib,importlib.util,shutil
import numpy as np
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(name,p):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--source-root',type=Path,default=R);ap.add_argument('--catalog',type=Path,default=R/'network/styles19');ap.add_argument('--out',type=Path,default=R/'work/style_export');args=ap.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
 source=args.source_root.resolve();catalog=json.loads((args.catalog/'source_models.json').read_text())
 gen=load('generator',R/'tools/generate_glass_int8.py');pack=load('packer',R/'tools/pack_glass_pipeline_weights.py')
 archive=bytearray(b'\xff'*(len(catalog)*16384));shape=None
 for item in catalog:
  base=out/item['name']/'source';(base/'parameters').mkdir(parents=True,exist_ok=True)
  for name,entry in item['files'].items():
   original=(source/entry['path']).resolve();assert original.is_relative_to(source)
   assert sha(original)==entry['sha256'],('Pinned model changed',original)
   shutil.copy2(original,base/name)
  graph=json.loads((base/'parameters/graph.json').read_text());nodes=graph['nodes']
  if shape is None:shape=nodes
  assert shape==nodes and '/8192' in graph['center_contract'] and graph['rgb_shift']==24
  rom=out/item['name'];gen.N=base;gen.O=rom;gen.main()
  with np.load(base/'parameters/model_int8.npz',allow_pickle=False) as p:
   packed,desc=pack.encode(p,json.loads((rom/'architecture.json').read_text()))
   w=b''.join(int(v,16).to_bytes(72,'little') for v in packed['packed_weights.mem'].split())
   c=b''.join(((int(v,16)>>(lane*77))&((1<<77)-1)).to_bytes(10,'little') for v in (rom/'coeff.mem').read_text().split() for lane in range(8))
   scalars=[int(p[n['name']+'.skip_multiplier'][0]) for n in nodes]+[int(v) for k in ['rgb.multiplier','rgb.bias'] for v in p[k]]
   payload=w+c+b''.join((v&0xffffffff).to_bytes(4,'little') for v in scalars)
  assert len(payload)==14448 and hashlib.sha256(payload).hexdigest()==item['payload_sha256']
  offset=item['id']*16384;header=struct.pack('<8I',0x4d534641,1,item['id'],len(payload),zlib.crc32(payload),0,0,0)
  archive[offset:offset+32+len(payload)]=header+payload
 (out/'parameters.bin').write_bytes(archive);(out/'parameters.hex').write_text(''.join(f'{b:02x}\n' for b in archive))
 pinned=json.loads((args.catalog/'manifest.json').read_text())
 assert sha(out/'parameters.bin')==pinned['sha256'],'Archive differs from validated selected set'
 result=dict(status='PASS',models=len(catalog),bytes=len(archive),sha256=sha(out/'parameters.bin'),note='Separate model image only; no Flash write performed')
 (out/'export_check.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
if __name__=='__main__':main()
