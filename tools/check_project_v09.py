"""Fail closed on v09 integration, exact ROMs/firmware and unchanged board clocks."""
import argparse,json
from pathlib import Path
from check_project_v06 import check
from check_project_v05 import sha
R=Path(__file__).resolve().parents[1]
N=R/'network/S8_480x270_Pipeline_v2_20261010/S8_480x270_Pipeline_v2'
def main():
    p=argparse.ArgumentParser();p.add_argument('--snapshot',action='store_true');p.add_argument('--check-snapshot',action='store_true');a=p.parse_args()
    sources,_=check()
    for f in ['rtl/video/cam_fb_pipe_v09.v','rtl/cnn/s8_shared_flat.v',*[f'rtl/accel/artflow_cnn_{n}.v' for n in ['bridge','resize','dma']]]:assert f in sources,f
    top=(R/'rtl/ArtFlow_top.v').read_text(encoding='utf-8')
    assert 'cam_fb_pipe_v09 #(' in top and '.VERSION_DIGIT("9")' in top and '.PROCESS_FPS(1)' in top
    assert 'gamma_display_rgb)' in top and '.o_display_rgb(hdmi_display_rgb)' in top
    assert (R/'rtl/cnn/s8_shared_flat.v').read_text()==(N/'s8_shared_flat.v').read_text().replace('"mem/','"rtl/cnn/')
    for f in (N/'mem').glob('*.mem'):assert sha(f)==sha(R/'rtl/cnn'/f.name),f
    baseline=json.loads((R/'doc/v09_baseline.json').read_text())
    for f in ['ArtFlow.peri.xml','ArtFlow.sdc']:
        assert sha(R/f)==baseline['board_inputs'][f],'Board configuration changed: '+f
    for f,digest in baseline['network_inputs'].items():assert sha(R/f)==digest,'Network source changed: '+f
    snap=R/'work/implementation_source_sha256.json'
    if a.snapshot:snap.write_text(json.dumps(sources,indent=2)+'\n')
    if a.check_snapshot:assert json.loads(snap.read_text())==sources,'Stale implementation'
    print('V09 PROJECT PASS:',len(sources),'inputs; frozen S8 model; original board PLL/pins/constraints')
if __name__=='__main__':main()
