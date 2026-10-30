from pathlib import Path
import json,subprocess,sys,shutil
R=Path(__file__).resolve().parents[1];(R/'reports/styles8').mkdir(exist_ok=True)
def run(*a):subprocess.run([sys.executable,'-B',*map(str,a)],cwd=R,check=True)
spec=json.loads((R/'tools/styles8_tests.json').read_text())
layout=['rtl/video/artflow_ui.v','rtl/video/artflow_button.v','rtl/video/artflow_fps.v','rtl/video/rgb_frame_store_v07.v','baseline/rgb_frame_store_v07_baseline.v','rtl/video/rgb_frame_store.v','rtl/video/video_axi_scheduler.v','rtl/frame_buffer/DC_FIFO.v','rtl/frame_buffer/rst_n_piple.v','sim/axi_memory_v07.sv','sim/tb_osd_layout_equivalence.sv']
cases={'fps_edges':['osd_fps_edges','rtl/video/artflow_fps.v','sim/tb_osd_fps_edges.sv'],'layout_equivalence':['osd_layout_equivalence',*layout],**{k:spec[k] for k in ['pair_control','style_cycle','system']}}
for k,c in cases.items():
 p=R/'work'/('osd_reg_'+k)/'summary.json'
 if p.exists():
  d=json.loads(p.read_text());assert d['status']=='PASS',str(p)
  import hashlib
  for f,h in {**d.get('source_sha256',{}),**d.get('vector_sha256',{})}.items():assert hashlib.sha256((R/f).read_bytes()).hexdigest()==h,f
 else:run('tools/run_rtl_case.py',c[0],'osd_reg_'+k,*c[1:])
for script in ['run_stream_rtl.py','run_shared_tests.py','run_reset_equivalence.py','run_tap_rtl.py']:run('stream/scripts/'+script)
run('tools/test_stream_esp.py')
(R/'reports/regression_complete.json').write_text(json.dumps({'status':'PASS','cases':list(cases),'stream':['SPI framing','RTL-to-C','reset equivalence','frame tap','ESP host tests']},indent=2))
