from pathlib import Path
import json,re,hashlib
from check_round23t_project import verify,SNAP,W
R=Path(__file__).resolve().parents[1];verify();assert json.loads((W/'pnr_summary.json').read_text())['status']=='PASS';assert json.loads((W/'normal_sta_summary.json').read_text())['status']=='PASS'
a=json.loads((R/'reports/round23t_map_analysis.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();mp=W/'out/ArtFlow.map.v';assert sha(mp)==a['sha256'][mp.relative_to(R).as_posix()]
ram=a['native_return_RAM'];names={x['instance'] for x in ram};assert len(names)==7
for x in ram:
 assert x['kind']=='EFX_RAM10' and x['ports']['WCLK']=='core_clk' and x['ports']['RCLK']=='cnn_clk'
 assert x['ports']['RST']=="1'b0" and "OUTPUT_REG=1'b0" in x['attributes'] and 'WRITE_MODE="READ_UNKNOWN"' in x['attributes']
log=(W/'sta_tclsh.log').read_text();seen=re.findall(r'RETURN_RAM_CELL (\S+)',log);assert len(seen)==7 and set(seen)==names
bound=['ArtFlow.sdc','tools/check_round23t_return_ram_cdc_v2.py','tools/check_round23t_return_ram_v2.tcl','reports/round23t_map_analysis.json','reports/round23t_functional_receipt.json']
for p in [SNAP,W/'normal_sta_summary.json',W/'video_cdc_audit.sdc',W/'sta_tclsh.log',W/'out/ArtFlow.map.v',W/'out/ArtFlow.vdb',W/'out/ArtFlow.place',W/'out/ArtFlow.troutingtraces']:bound.append(p.relative_to(R).as_posix())
results={}
for role in ['write','address','data']:
 for kind in ['setup','hold']:
  p=W/f'out/ArtFlow.return_ram_{role}_{kind}.rpt';assert p.stat().st_mtime_ns>SNAP.stat().st_mtime_ns;bound.append(p.relative_to(R).as_posix());rows=[];covered=set()
  for b in re.split(r'\+\+\+\+ Path \d+ \++',p.read_text())[1:]:
   def field(key):
    m=re.search(r'^'+key+r'\s*:\s*(\S+)',b,re.M);assert m,key;return m[1]
   start=field('Path Start');end=field('Path End');slack=field('Slack');assert not slack.startswith('-'),'Negative RAM port timing';delay=float(field('Data Path Delay'))
   node=start if role=='data' else end;cell,pin=node.rsplit('|',1);assert cell in names,node;covered.add(cell)
   if role=='write':assert re.fullmatch(r'(WDATA|WADDR|WE|WADDREN|WCLKE)(\[\d+\])?',pin),pin
   elif role=='address':assert re.fullmatch(r'(RADDR|RE|RADDREN)(\[\d+\])?',pin),pin
   else:assert pin=='RCLK',pin
   rows.append(dict(start=start,end=end,slack_ns=float(slack),delay_ns=delay))
  assert rows and covered==names,(role,kind,'Incomplete nativeRAM port coverage',covered)
  results[role+'_'+kind]=dict(paths=len(rows),minimum_slack_ns=min(x['slack_ns'] for x in rows),maximum_data_delay_ns=max(x['delay_ns'] for x in rows),covered_RAM=sorted(covered))
result=dict(status='PASS',RAM_count=7,port_timing=results,scope='Reviewed native dual-clock payload memory. Independent core-clock write and CNN-clock read ports, no extra output pipeline stage. Same-clock write/address/data setup+hold audited for every RAM. All Gray/lease CDC checks remain separate and mandatory; no raw payload CDC exception added. Functional collision/reset/capacity tests bound in receipt.',sha256={n:sha(R/n) for n in bound})
(W/'return_ram_cdc_summary.json').write_text(json.dumps(result,indent=2));print('NATIVE_RETURN_RAM_CDC_PASS',results)
