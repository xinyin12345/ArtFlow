from pathlib import Path
import json,re,hashlib,collections
from check_round23t_project import verify,W
from map_hierarchy import hierarchy
R=Path(__file__).resolve().parents[1];verify();assert json.loads((W/'map_summary.json').read_text())['status']=='PASS'
mp=W/'out/ArtFlow.map.v';t=mp.read_text();ram=[]
for m in re.finditer(r'^\s*(EFX_\w+)\s+(\\[^\s]+|\w+)\s+\((.*?)\)\s*(?:/\*(.*?)\*/\s*)?;',t,re.M|re.S):
 kind,inst,body,attrs=m.groups();inst=inst.lstrip('\\')
 if '/u_accel_dma/r/' in inst and 'RAM' in kind:
  ports={n:' '.join(v.split()).lstrip('\\') for n,v in re.findall(r'\.(\w+)\(([^()]*)\)',body)};ram.append(dict(kind=kind,instance=inst,ports=ports,attributes=attrs))
assert len(ram)==7
for x in ram:
 assert x['kind']=='EFX_RAM10' and x['ports']['WCLK']=='core_clk' and x['ports']['RCLK']=='cnn_clk' and x['ports']['RST']=="1'b0"
 for token in ['READ_WIDTH=20','WRITE_WIDTH=20',"OUTPUT_REG=1'b0",'WRITE_MODE="READ_UNKNOWN"']:assert token in x['attributes']
h=hierarchy('styles8');res={k:v['total'] for k,v in h['ArtFlow_top'].items()};assert res['ram']<=256 and res['dsp']<=160
p=W/'map_warnings_snapshot.log';assert not p.exists();p.write_bytes((W/'out/ArtFlow.info.log').read_bytes());warnings=[l for l in p.read_text(errors='replace').splitlines() if re.match(r'^\[EFX-[^\]]*(?:WARNING|ERROR)\]',l)]
files=[mp,W/'out/ArtFlow.map.rpt',W/'out/ArtFlow.vdb',W/'map_summary.json',p,R/'reports/styles8/round23t_functional_receipt.json']
d=dict(status='PASS',resources=res,native_return_RAM=ram,warnings=warnings,sha256={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files},pnr_allowed=False)
(R/'reports/styles8/round23t_map_analysis.json').write_text(json.dumps(d,indent=2));print('MAP_ANALYSIS',res,'RETURN_RAM',len(ram),'WARNINGS',len(warnings));print('\n'.join(warnings))
