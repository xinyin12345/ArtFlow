"""Check production tag alignment through pattern/gamma at every pixel boundary."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys
R=Path(__file__).resolve().parents[1]
out=R/'work/v09/color';out.mkdir(parents=True,exist_ok=True)
top=R/'rtl/ArtFlow_top.v';s=top.read_text(encoding='utf-8')
block=s[s.index('reg pat_display_rgb'):s.index('wire [7:0] gamma_rdata')]
block=block.replace('hdmi_tx_slow_clk','clk').replace('vid_rst_n','rst_n').replace('hdmi_display_rgb','tag')
(out/'color_tag_block.vh').write_text(block)
paths=[R/'sim/tb_v09_color.sv',R/'rtl/video/test_pattern.v',R/'rtl/gamma_conrrection/gamma_lut.v']
inputs=paths+[top,R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem',Path(__file__)]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
iv=R/'work/v07/tools/ucrt64/bin';env=os.environ.copy();env['PATH']=str(iv)+os.pathsep+r'C:\msys64\ucrt64\bin'+os.pathsep+r'C:\Windows\System32'
status='FAIL';limits=[]
try:
    (out/'test.vvp').unlink(missing_ok=True)
    with (out/'compile.log').open('w') as f:
        c=subprocess.run([str(iv/'iverilog.exe'),'-v','-g2012','-s','tb_v09_color','-I',str(out),'-o',str(out/'test.vvp'),*map(str,paths)],cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
    txt=(out/'compile.log').read_text(errors='replace')
    if c.returncode in (3221225477,-1073741819) and 'DONE.' in txt and (out/'test.vvp').exists() and not re.search(r'error:|syntax error',txt):limits.append('Icarus exit fault after code emission')
    else:assert c.returncode==0,txt[-2500:]
    with (out/'simulation.log').open('w') as f:
        c=subprocess.run([str(iv/'vvp.exe'),str(out/'test.vvp')],cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
    txt=(out/'simulation.log').read_text();print(txt)
    assert c.returncode==0 and 'tb_v09_color PASS' in txt and not re.search(r'ERROR:|FATAL:',txt)
    status='PASS_WITH_TOOL_LIMITATIONS' if limits else 'PASS'
except Exception as e:print(e)
(out/'summary.json').write_text(json.dumps(dict(status=status,tool_limitations=limits,source_sha256={p.relative_to(R).as_posix():sha(p) for p in inputs},evidence_sha256={p.name:sha(p) for p in out.glob('*.log')}),indent=2)+'\n')
sys.exit(status=='FAIL')
