"""Check the active v07 top, sources and the exact initialized firmware."""
import argparse,json
from pathlib import Path
from check_project_v06 import check
ROOT=Path(__file__).resolve().parents[1]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--snapshot',action='store_true');ap.add_argument('--check-snapshot',action='store_true');a=ap.parse_args()
    sources,_=check()
    for name in ('artflow_accel_ctrl','artflow_accel_dma','artflow_axi_mux'):
        assert 'rtl/accel/'+name+'.v' in sources, 'Missing accelerator source '+name
    top=(ROOT/'rtl/ArtFlow_top.v').read_text(encoding='utf-8')
    assert 'cam_fb_pipe_v07 #(' in top and '.VERSION_DIGIT("7")' in top and '.PROCESS_FPS(1)' in top
    assert '.accel_irq(accel_irq)' in top
    assert '.userInterruptA(accel_irq)' in (ROOT/'rtl/control/artflow_soc.v').read_text()
    snapshot=ROOT/'work/implementation_source_sha256.json'
    if a.snapshot:snapshot.parent.mkdir(parents=True,exist_ok=True);snapshot.write_text(json.dumps(sources,indent=2)+'\n')
    if a.check_snapshot:assert json.loads(snapshot.read_text())==sources,'Stale implementation'
    print('V07 PROJECT PASS:',len(sources),'inputs; v07 shell, APB, IRQ and OSD selected')
if __name__=='__main__':main()
