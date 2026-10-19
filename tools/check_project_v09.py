"""Fail closed on v09 integration, exact ROMs/firmware and unchanged board clocks."""
import argparse,json,subprocess
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
    # Execution RTL may be pipelined; immutable original graph/ROMs and the
    # complete per-layer integer scoreboard guard arithmetic equivalence.
    for f in (N/'mem').glob('*.mem'):assert sha(f)==sha(R/'rtl/cnn'/f.name),f
    baseline=json.loads((R/'doc/v09_baseline.json').read_text())
    # Allow exactly one additional PLL output and its clock-domain constraint.
    # Existing DDR/camera/HDMI/CPU clocks, pins and timing exceptions stay exact.
    for f in ['ArtFlow.peri.xml','ArtFlow.sdc']:
        old=subprocess.check_output(['git','show','5c2218c:'+f],cwd=R).decode()
        now=(R/f).read_bytes().decode()
        if f.endswith('.xml'):
            addition='            <efxpt:comp_output_clock name="cnn_clk" number="1" out_divider="9" is_dyn_phase="false" phase_setting="0" is_inverted="false" conn_type="gclk"/>\r\n'
            expected=old.replace('            <efxpt:comp_output_clock name="core_clk"',addition+'            <efxpt:comp_output_clock name="core_clk"')
        else:
            expected=old.replace('create_clock -period 10.000 -name core_clk','create_clock -period 4.500 -name cnn_clk [get_ports {cnn_clk}]\r\ncreate_clock -period 10.000 -name core_clk')
            expected=expected.replace('-group {core_clk} -group','-group {core_clk} -group {cnn_clk} -group')
        assert now==expected,'Unexpected board configuration change: '+f
    for f,digest in baseline['network_inputs'].items():assert sha(R/f)==digest,'Network source changed: '+f
    snap=R/'work/implementation_source_sha256.json'
    if a.snapshot:snap.write_text(json.dumps(sources,indent=2)+'\n')
    if a.check_snapshot:assert json.loads(snap.read_text())==sources,'Stale implementation'
    print('V09 PROJECT PASS:',len(sources),'inputs; frozen S8 model; dedicated 222.222 MHz CNN, original board clocks/pins')
if __name__=='__main__':main()
