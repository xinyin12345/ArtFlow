from pathlib import Path
import re,json,hashlib,sys
R=Path(__file__).resolve().parents[1];F=R.parent;W=F/'work/styles15';O=W/'out'
def prepare():
 p=W/'video_cdc_audit.sdc';s=p.read_text()
 for port,reg in [('stream_ready','ready_meta'),('stream_miso','miso_meta')]:
  line=next(l for l in s.splitlines() if l.startswith('set_false_path -from [get_ports {'+port+'}]'))
  s=s.replace(line,'# AFS first-stage exception removed only for pad route measurement.')
  s+='\nset_input_delay -clock hdmi_tx_slow_clk -max 0 [get_ports '+port+']\nset_input_delay -clock hdmi_tx_slow_clk -min 0 [get_ports '+port+']\nset_max_delay 10 -from [get_ports '+port+'] -to [get_pins {u_stream/packet/'+reg+'~FF|D}]\n'
 s+='\nset_output_delay -clock hdmi_tx_slow_clk -max 0 [get_ports {stream_sclk stream_mosi stream_cs_n}]\nset_output_delay -clock hdmi_tx_slow_clk -min 0 [get_ports {stream_sclk stream_mosi stream_cs_n}]\n';p.write_text(s)
 t=''
 for port,reg in [('stream_ready','ready_meta'),('stream_miso','miso_meta')]:
  t+='if {[llength [get_cells u_stream/packet/'+reg+'~FF]] != 1} {error "Missing AFS first stage '+reg+'"}\n'
  t+='report_timing -setup -from [get_ports '+port+'] -to [get_cells u_stream/packet/'+reg+'~FF] -npaths 1 -file ArtFlow.afs_'+port+'.rpt\n'
  sync=reg.replace('_meta','_sync')
  t+='if {[llength [get_cells u_stream/packet/'+sync+'~FF]] != 1} {error "Missing AFS second stage '+sync+'"}\n'
  t+='report_timing -setup -from [get_cells u_stream/packet/'+reg+'~FF] -to [get_cells u_stream/packet/'+sync+'~FF] -npaths 1 -file ArtFlow.afs_'+sync+'.rpt\n'
 for port in ['stream_sclk','stream_mosi','stream_cs_n']:
  t+='report_timing -setup -to [get_ports '+port+'] -npaths 1 -file ArtFlow.afs_'+port+'.rpt\n'
 with (W/'audit.tcl').open('a') as f:f.write(t)
def check():
 vals={};paths={}
 for n in ['stream_ready','stream_miso','ready_sync','miso_sync','stream_sclk','stream_mosi','stream_cs_n']:
  p=O/('ArtFlow.afs_'+n+'.rpt');s=p.read_text();assert p.stat().st_mtime_ns>(W/'implementation_source_sha256.json').stat().st_mtime_ns
  delay=re.findall(r'^Data Path Delay\s*:\s*(-?\d+\.\d+)',s,re.M);assert len(delay)==1,(n,s)
  v=float(delay[0]);bound=2.5 if n.endswith('_sync') else 10;assert 0<=v<=bound,(n,v)
  start=re.findall(r'^Path Start\s*:\s*(\S+)',s,re.M);end=re.findall(r'^Path End\s*:\s*(\S+)',s,re.M);assert len(start)==len(end)==1
  if n in ['stream_ready','stream_miso']:assert start==[n] and end==['u_stream/packet/'+n.replace('stream_','')+'_meta~FF|D'],(n,start,end)
  elif n.endswith('_sync'):assert start==['u_stream/packet/'+n.replace('_sync','_meta')+'~FF|CLK'] and end==['u_stream/packet/'+n+'~FF|D']
  else:assert end==[n] and start[0].endswith('~FF|CLK')
  vals[n]=v;paths[n]={'start':start[0],'end':end[0],'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 # Conditional electrical budget, not an ESP datasheet guarantee or board measurement.
 budget=vals['stream_sclk']+4+25+vals['stream_miso']+2
 assert budget<4*1000/74.25,('Conditional SPI round trip has insufficient margin',budget)
 (W/'stream_io_summary.json').write_text(json.dumps({'status':'PASS_CONDITIONAL_EXTERNAL_BUDGET','routes_ns':vals,'path_evidence':paths,'external_assumptions':{'wire_ns':4,'esp_launch_ns':25,'setup_margin_ns':2},'round_trip_ns':budget,'available_ns':4*1000/74.25,'hardware_tested':False},indent=2));print('AFS IO/CDC routes PASS; external timing assumptions require board test',vals)
if __name__=='__main__':{'prepare':prepare,'check':check}[sys.argv[1]]()
