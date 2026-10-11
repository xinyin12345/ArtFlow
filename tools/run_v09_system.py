"""Camera/frame ownership, real CNN, AXI arbitration, APB IRQ and display regression."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys
import numpy as np
R=Path(__file__).resolve().parents[1]
N=R/'network/S8_480x270_Pipeline_v2_20261010/S8_480x270_Pipeline_v2'
sys.path.insert(0,str(N/'reference'))
from integer_model import IntegerS8
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    out=R/'work/v09/system';out.mkdir(parents=True,exist_ok=True)
    paths=[*sorted((R/'rtl/accel').glob('*.v')),R/'rtl/cnn/s8_shared_flat.v',*[R/p for p in [
        'rtl/video/bayer_bin2x2.v','rtl/video/rgb_frame_store.v','rtl/video/rgb_frame_store_v07.v',
        'rtl/video/cam_fb_pipe_v09.v','rtl/video/video_axi_scheduler.v','rtl/frame_buffer/DC_FIFO.v',
        'rtl/frame_buffer/rst_n_piple.v','sim/axi_memory_v09.sv','sim/tb_v09_system.sv']]]
    evidence=paths+list((R/'rtl/cnn').glob('*.mem'))+[Path(__file__),R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem']
    hashes={p.relative_to(R).as_posix():sha(p) for p in evidence}
    (out/'summary.json').write_text('{"status":"RUNNING"}')
    iv=R/'work/v07/tools/ucrt64/bin';env=os.environ.copy();env['PATH']=str(iv)+os.pathsep+r'C:\msys64\ucrt64\bin'+os.pathsep+r'C:\Windows\System32'
    limits=[];status='FAIL';pixels=0
    try:
        (out/'test.vvp').unlink(missing_ok=True)
        with (out/'compile.log').open('w') as f:
            c=subprocess.run([str(iv/'iverilog.exe'),'-v','-g2012','-s','tb_v09_system','-o',str(out/'test.vvp'),*map(str,paths)],cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
        txt=(out/'compile.log').read_text(errors='replace')
        if c.returncode in (3221225477,-1073741819) and 'DONE.' in txt and (out/'test.vvp').exists() and not re.search(r'error:|syntax error',txt):limits.append('Icarus exit fault after code emission')
        else:assert c.returncode==0,txt[-4000:]
        with (out/'simulation.log').open('w') as f:
            c=subprocess.run([str(iv/'vvp.exe'),str(out/'test.vvp')],cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=600)
        txt=(out/'simulation.log').read_text(errors='replace');print(txt,flush=True)
        assert c.returncode==0 and 'tb_v09_system PASS' in txt and not re.search(r'ERROR:|FATAL:',txt)
        src=np.array([int(x,16) for x in (R/'work/v09/system_input.hex').read_text().split()],np.int64)
        dst=np.array([int(x,16) for x in (R/'work/v09/system_output.hex').read_text().split()],np.int64)
        assert len(src)==len(dst) and len(src)%896==0
        lut=np.array([int(x,16) for x in (R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem').read_text().split()])
        model=IntegerS8(N/'reference/exports')
        for k in range(0,len(src),896):
            a=src[k:k+896].reshape(28,32);rgb=np.stack([(a>>16)&255,(a>>8)&255,a&255],axis=-1)
            lo=(rgb[::2,::2]+rgb[1::2,::2]+rgb[::2,1::2]+rgb[1::2,1::2]+2)//4
            lo=lut[lo].astype(np.uint8).transpose(2,0,1)[None]
            styled=model.forward(np.pad(lo,((0,0),(0,0),(0,2),(0,0)),mode='reflect'))[0,:,:14,:].transpose(1,2,0).astype(np.int64)
            up=np.zeros((28,32,3),np.int64)
            for y in range(28):
                for x in range(32):
                    y0,fy=divmod(2*y-1,4);x0,fx=divmod(2*x-1,4)
                    for dy,wy in [(0,4-fy),(1,fy)]:
                        for dx,wx in [(0,4-fx),(1,fx)]:up[y,x]+=styled[max(0,min(13,y0+dy)),max(0,min(15,x0+dx))]*wy*wx
            up=(up+8)//16;expected=(1<<24)|(up[:,:,0]<<16)|(up[:,:,1]<<8)|up[:,:,2]
            assert np.array_equal(expected.ravel(),dst[k:k+896]),f'CNN system pixel mismatch frame {k//896}'
            pixels+=896
        assert hashes=={p.relative_to(R).as_posix():sha(p) for p in evidence},'Sources changed during regression'
        status='PASS_WITH_TOOL_LIMITATIONS' if limits else 'PASS'
    except Exception as e:print(type(e).__name__,e,flush=True)
    (out/'summary.json').write_text(json.dumps(dict(status=status,pixels=pixels,tool_limitations=limits,source_sha256=hashes,evidence_sha256={p.name:sha(p) for p in out.glob('*.log')}),indent=2)+'\n')
    print(status,flush=True);return status=='FAIL'
if __name__=='__main__':sys.exit(main())
