from pathlib import Path
import re,json,collections,hashlib
R=Path(__file__).resolve().parents[1]
def hierarchy(name):
 t=(R/f'work/{name}/out/ArtFlow.map.rpt').read_text();out={};stack=[]
 for line in t.splitlines():
  m=re.match(r'^(\s*)(\+?)(.*?)\s+((?:\d+\(\d+\)\s*){7})$',line)
  if not m:continue
  depth=len(m[1]);inst=m[3].strip().split(':',1)[0];values=[tuple(map(int,x)) for x in re.findall(r'(\d+)\((\d+)\)',m[4])]
  if not m[2]:depth=0
  stack=stack[:depth];stack.append(inst);path='/'.join(stack);assert path not in out,path
  out[path]={key:dict(total=v[0],direct=v[1]) for key,v in zip(['ff','srl','add','lut','comb','ram','dsp'],values)}
 for key in ['ff','srl','add','lut','ram','dsp']:assert sum(v[key]['direct'] for v in out.values())==out['ArtFlow_top'][key]['total']
 return out
