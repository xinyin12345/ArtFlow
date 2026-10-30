from pathlib import Path
import sys,subprocess,json,shutil,re,hashlib
R=Path(__file__).resolve().parents[1];W=R/'work/osd_impl';sys.path.insert(0,str(R/'tools'))
from check_osd_sources import verify
def run(name,*args):subprocess.run([sys.executable,'-B',str(R/name),*args],cwd=R,check=True)
verify()
route=(W/'out/ArtFlow.route.out').read_text(errors='replace')
assert 'Routing Succeeded' in route and re.search(r'overlap=0\s',route), 'No legal-route proof'
assert not re.search(r'Routing Failed|Route Failed',route), 'Route failure'
run('tools/osd_audit_timing.py')
for n in ['video_cdc','cnn_cdc','style_io']:run('tools/osd_audit_'+n+'.py','prepare')
(W/'audit.tcl').write_text('\n'.join((R/'tools'/n).read_text() for n in ['check_video_cdc.tcl','check_osd_ui_cdc.tcl','check_cnn_cdc.tcl','check_al_lease_cdc.tcl','check_style_io.tcl','check_round23t_return_ram_v2.tcl','check_osd_mailbox.tcl']))
run('stream/scripts/osd_stream_io_audit.py','prepare')
run('tools/run_osd_flow.py','sta_tclsh')
for n in ['cnn','ui']:shutil.copy2(W/'sta_tclsh.log',W/(n+'_cdc.log'))
for n in ['video_cdc','cnn_cdc','style_io']:run('tools/osd_audit_'+n+'.py','check')
run('tools/osd_audit_ui_cdc.py');run('tools/osd_audit_return_ram_cdc_v2.py');run('stream/scripts/osd_stream_io_audit.py','check')
result={}
for name in ['req1_setup','req1_hold','req2_setup','req2_hold','ack1_setup','ack1_hold',*[f'data_{i}' for i in range(4)]]:
 p=W/f'out/ArtFlow.osd_{name}.rpt';s=p.read_text()
 def field(k):
  a=re.findall(r'^'+k+r'\s*:\s*(\S+)',s,re.M);assert len(a)==1,(name,k);return a[0]
 delay=float(field('Data Path Delay'));slack=float(field('Slack'));a=field('Path Start');b=field('Path End')
 assert 0<=delay<=(13.468 if name.startswith('data') else 2.5),(name,delay)
 if not name.startswith('data'):assert slack>=0,(name,slack)
 else:
  bit=name.split('_')[1];assert a==f'u_video_pipe/u_store/osd_payload[{bit}]~FF|CLK' and b==f'u_video_pipe/u_store/osd_pending[{bit}]~FF|D'
 result[name]=dict(start=a,end=b,data_delay_ns=delay,slack_ns=slack,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
(R/'reports/osd_cdc.json').write_text(json.dumps({'status':'PASS','paths':result,'payload_budget_ns':13.468,'protocol':'held bundled data, 3-stage request, 2-stage returned acknowledgement'},indent=2))
assert json.loads((R/'reports/pixel_comparison.json').read_text())['status']=='PASS'
functional=json.loads((R/'reports/regression_complete.json').read_text())
assert functional['status']=='PASS' and functional.get('revision')=='CAP_OUT', 'Fresh source-associated CAP/OUT receipt required'
verify()
audit_sources=list((R/'tools').glob('osd_audit_*.py'))+list((R/'tools').glob('check_*.tcl'))+[R/'tools/run_osd_audits.py',R/'tools/check_osd_sources.py',R/'tools/styles15_timing.py',R/'stream/scripts/osd_stream_io_audit.py']
audit_hashes={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in audit_sources}
(R/'reports/physical_gate.json').write_text(json.dumps({'status':'PASS','revision':'CAP_OUT','audit_scripts_sha256':audit_hashes,'source_snapshot_sha256':hashlib.sha256((W/'implementation_source_sha256.json').read_bytes()).hexdigest(),'functional_receipt_sha256':hashlib.sha256((R/'reports/regression_complete.json').read_bytes()).hexdigest(),'normal_setup_hold':json.loads((W/'normal_sta_summary.json').read_text()),'route_legal':True,'cdc':'video/cnn/ui/style/stream/nativeRAM/newOSD PASS','hardware_tested':False,'programmed':False},indent=2))
print('PASS physical release gates; no hardware programmed')
