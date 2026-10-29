from pathlib import Path
import json,re,hashlib
from check_round23t_project import verify as implementation_sources,SNAP
from styles15_timing import parse_timing
r=Path(__file__).resolve().parents[1];o=r/'work/styles8/out'
assert implementation_sources()==json.loads(SNAP.read_text())
assert json.loads((o.parent/'pnr_summary.json').read_text())['status']=='PASS'
p=o/'ArtFlow.timing.rpt';t=p.read_text();assert 'Preliminary' not in t,'Final routed timing report required';slack=parse_timing(t)
for section,end in [('Setup (Max)','Hold (Min)'),('Hold (Min)','NOTE:')]:
 block=t.split(section+' Clock Relationship',1)[1].split(end,1)[0]
 assert re.search(r'^\s*cnn_clk\s+cnn_clk\s+',block,re.M),'Missing CNN clock timing'
# Independently inspect every edge row, not just R-R, and detailed signed slacks.
for section,end in [('Setup (Max)','Hold (Min)'),('Hold (Min)','NOTE:')]:
 block=t.split(section+' Clock Relationship',1)[1].split(end,1)[0]
 edge_lines=[line for line in block.splitlines() if re.search(r'\([RF]-[RF]\)',line)]
 assert edge_lines,'Missing edge relationships'
 for line in edge_lines:
  m=re.fullmatch(r'\s*(\S+)\s+(\S+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\([RF]-[RF]\)\s*',line)
  assert m and not m[4].startswith('-'),'Unparsed or negative timing row: '+line
 for clock in ['sdram_clk','tx_cal_clk','tx_cal_clk_90edge','rx_cal_clk','vid_clk_dvi2','hdmi_tx_slow_clk','cnn_clk','core_clk','i_mipi_rx_pclk','i_cam_ck_CLKOUT']:
  assert any(re.match(r'\s*'+re.escape(clock)+r'\s+'+re.escape(clock)+r'\s',line) for line in edge_lines),'Missing clock '+clock
assert not re.search(r'^\s*Slack\s*:\s*-',t,re.M),'Negative detailed slack'
assert p.stat().st_mtime_ns>SNAP.stat().st_mtime_ns,'Stale STA'
result={'status':'PASS','minimum_slack_ns':slack,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source_snapshot_sha256':hashlib.sha256(SNAP.read_bytes()).hexdigest()}
(o.parent/'normal_sta_summary.json').write_text(json.dumps(result,indent=2));print('Normal A timing PASS',slack)
