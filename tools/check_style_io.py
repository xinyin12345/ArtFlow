from pathlib import Path
import sys,json,re,hashlib
R=Path(__file__).resolve().parents[1];W=R/'work/glass_int8';O=W/'efinity_out'
def prepare():
 for name in ['video_cdc_audit.sdc','cnn_cdc_audit.sdc']:
  p=W/name;t=p.read_text();line=next(s for s in t.splitlines() if s.startswith('set_false_path -from [get_ports {flash_miso}]'))
  t=t.replace(line,'# SPI first-stage exception removed only to measure its pad-to-D delay.')
  t+='\n# Artificial launch/capture edges for measuring IO routing, not synchronous signoff.\nset_input_delay -clock cnn_clk -max 0 [get_ports flash_miso]\nset_input_delay -clock cnn_clk -min 0 [get_ports flash_miso]\nset_max_delay 10 -from [get_ports flash_miso] -to [get_pins {u_video_pipe/u_accel_dma/styles.banks/reader/miso_meta~FF|D}]\nset_output_delay -clock cnn_clk -max 0 [get_ports {flash_sck flash_mosi flash_cs_n}]\nset_output_delay -clock cnn_clk -min 0 [get_ports {flash_sck flash_mosi flash_cs_n}]\n';p.write_text(t)
def check():
 routes={};files=['ArtFlow.sdc','rtl/cnn/glass_int8/style_spi_reader.v','tools/check_style_io.tcl','tools/check_style_io.py','work/glass_int8/video_cdc_audit.sdc','work/glass_int8/implementation_source_sha256.json']
 for name in ['input','flash_sck','flash_mosi','flash_cs_n']:
  p=O/f'ArtFlow.spi_{name}.rpt';t=p.read_text();assert p.stat().st_mtime_ns>(W/'implementation_source_sha256.json').stat().st_mtime_ns
  delays=re.findall(r'^Data Path Delay\s*:\s*(-?\d+\.\d+)',t,re.M);assert len(delays)==1,(name,t[-2000:]);v=float(delays[0]);assert 0<=v<=10,(name,v)
  start=re.findall(r'^Path Start\s*:\s*(\S+)',t,re.M);end=re.findall(r'^Path End\s*:\s*(\S+)',t,re.M)
  assert start==(['flash_miso'] if name=='input' else [name+'~FF|CLK']),(name,start)
  assert end==(['u_video_pipe/u_accel_dma/styles.banks/reader/miso_meta~FF|D'] if name=='input' else [name]),(name,end)
  routes[name]=v;files.append(str(p.relative_to(R)))
 # Datasheet GD25LQ64C Rev3.4 max DO valid=7 ns at 30 pF. Two synchronized
 # sampling clocks plus clock/PCB IO route budget must fit the 8-clock low half.
 bound=routes['flash_sck']+7+2+routes['input']+14+2
 assert bound<56,('SPI round trip exceeds low interval',bound)
 result=dict(status='PASS',pad_route_ns=routes,round_trip_budget_ns=bound,available_ns=56,pcb_round_trip_allowance_ns=2,flash_tCLQV_ns=7,
  note='Protocol timing budget with two-FF input synchronization; board flash suffix/load/trace flight allowance needs physical validation. No phase-locked SPI clock assumed.',
  datasheet='https://www.mouser.lt/datasheet/2/870/gd25lq64c_rev3_4_20190615-2486443.pdf',sha256={n:hashlib.sha256((R/n).read_bytes()).hexdigest() for n in files})
 (W/'style_io_cdc_summary.json').write_text(json.dumps(result,indent=2));print('SPI IO ROUTE PASS',routes,'round-trip',bound)
if __name__=='__main__':{'prepare':prepare,'check':check}[sys.argv[1]]()
