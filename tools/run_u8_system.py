"""Camera/frame ownership, real CNN, AXI arbitration, APB IRQ and display regression."""
from pathlib import Path
import hashlib,json,os,re,subprocess,sys
import numpy as np
R=Path(__file__).resolve().parents[1]
N=R/'network/Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60_20261014/XDL1_Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60'
sys.path.insert(0,str(N))
from golden import forward
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    out=R/'work/u8_integration/system';out.mkdir(parents=True,exist_ok=True)
    paths=[*sorted(p for p in (R/'rtl/accel').glob('*.v') if p.name!='artflow_glass_dma.v'),R/'rtl/cnn/student_u8/student_u8_flat.v',*[R/p for p in [
        'rtl/video/bayer_bin2x2.v','rtl/video/rgb_frame_store.v','rtl/video/rgb_frame_store_v07.v',
        'rtl/video/cam_fb_pipe_v09.v','rtl/video/video_axi_scheduler.v','rtl/frame_buffer/DC_FIFO.v',
        'rtl/frame_buffer/rst_n_piple.v','sim/axi_memory_v09.sv','sim/tb_u8_system.sv']]]
    evidence=[N/'golden.py',N/'architecture.json',*sorted((N/'reference').rglob('*.py')),*sorted((N/'reference/integer').glob('*'))]+paths+list((R/'rtl/cnn/student_u8').glob('*.mem'))+[Path(__file__),R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem']
    hashes={p.relative_to(R).as_posix():sha(p) for p in evidence}
    (out/'summary.json').write_text('{"status":"RUNNING"}')
    q=Path(r'D:\soft\Questa\questa_fse\win64')
    env=os.environ.copy();env['PATH']=str(q)+os.pathsep+env['PATH']
    limits=[];status='FAIL';pixels=0
    def call(stage,args,cwd=R):
        with (out/(stage+'.log')).open('w') as f:
            argv=[v.as_posix() if isinstance(v,Path) else str(v) for v in args[1:]]
            c=subprocess.run([str(q/(args[0]+'.exe')),*argv],cwd=cwd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1800)
        txt=(out/(stage+'.log')).read_text(errors='replace')
        assert c.returncode==0 and not re.search(r'\*\* (Error|Fatal):',txt),txt[-5000:]
        return txt
    try:
        call('version',['vsim','-version'])
        if not (out/'work').exists():call('vlib',['vlib',out/'work'])
        call('vmap_init',['vmap','-c'],cwd=out)
        ini=out/'modelsim.ini';call('vmap',['vmap','-modelsimini',ini,'work',out/'work'],cwd=out)
        call('compile',['vlog','-modelsimini',ini,'-work','work','-sv',*paths])
        txt=call('simulation',['vsim','-c','-ini',ini,'-wlf',out/'test.wlf','-l',out/'transcript.log',
            '-onfinish','exit','work.tb_u8_system','-do','run -all; quit -code 0'])
        print(txt[-5000:],flush=True)
        assert 'tb_u8_system PASS' in txt and not re.search(r'ERROR:|FATAL:',txt)
        src=np.array([int(x,16) for x in (R/'work/u8_integration/system_input.hex').read_text().split()],np.int64)
        dst=np.array([int(x,16) for x in (R/'work/u8_integration/system_output.hex').read_text().split()],np.int64)
        assert len(src)==len(dst) and len(src)%896==0
        lut=np.array([int(x,16) for x in (R/'rtl/gamma_conrrection/gamma_inv2p2_8b.mem').read_text().split()])
        for k in range(0,len(src),896):
            a=src[k:k+896].reshape(28,32);rgb=np.stack([(a>>16)&255,(a>>8)&255,a&255],axis=-1)
            lo=(rgb[::2,::2]+rgb[1::2,::2]+rgb[::2,1::2]+rgb[1::2,1::2]+2)//4
            lo=lut[lo].astype(np.uint8).transpose(2,0,1)[None]
            styled=forward(lo)[0][0,:,:14,:].transpose(1,2,0).astype(np.int64)
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
