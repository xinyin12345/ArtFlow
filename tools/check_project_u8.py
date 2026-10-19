"""Validate the frozen U8 model, permitted deployment transforms and board clocks."""
import argparse,json,re,subprocess
from pathlib import Path
from check_project_v06 import check
from check_project_v05 import sha
R=Path(__file__).resolve().parents[1]
N=R/'network/Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60_20261014/XDL1_Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60'
def main():
    p=argparse.ArgumentParser();p.add_argument('--snapshot',action='store_true');p.add_argument('--check-snapshot',action='store_true');a=p.parse_args()
    sources,_=check()
    for f in ['rtl/video/cam_fb_pipe_v09.v','rtl/cnn/student_u8/student_u8_flat.v',*[f'rtl/accel/artflow_cnn_{n}.v' for n in ['bridge','resize','dma']]]:assert f in sources,f
    top=(R/'rtl/ArtFlow_top.v').read_text(encoding='utf-8')
    assert 'cam_fb_pipe_v09 #(' in top and '.VERSION_DIGIT("9")' in top and '.PROCESS_FPS(1)' in top
    assert 'gamma_display_rgb)' in top and '.o_display_rgb(hdmi_display_rgb)' in top
    # Execution RTL may be pipelined; immutable original graph/ROMs and the
    # complete per-layer integer scoreboard guard arithmetic equivalence.
    for f in (N/'mem').glob('*.mem'):assert sha(f)==sha(R/'rtl/cnn/student_u8'/f.name),f
    original=(N/'student_u8_flat.v').read_text(encoding='utf-8')
    deployed=(R/'rtl/cnn/student_u8/student_u8_flat.v').read_text(encoding='utf-8')
    line=next(x for x in original.splitlines(True) if 'wire [15:0] line_waddr=' in x)
    original=original.replace(line,'').replace(' wire prefetch_response=mem_rvalid&&read_pending&&read_owner==2;\n',' wire prefetch_response=mem_rvalid&&read_pending&&read_owner==2;\n'+line)
    original=original.replace(' reg [95:0] brom[0:63];reg [83:0] mrom[0:63];reg [127:0] trom[0:63];',' (* syn_romstyle="logic" *) reg [95:0] brom[0:63];\n (* syn_romstyle="logic" *) reg [83:0] mrom[0:63];\n (* syn_romstyle="logic" *) reg [127:0] trom[0:63];')
    # Optimized scheduling is checked by the independent complete per-layer
    # scoreboard. Keep graph configuration and arithmetic modules exact.
    graph=lambda text: re.search(r'case\(layer_index\).*?endcase',text,re.S).group()
    module=lambda text,name: re.search(r'\bmodule '+name+r'\b.*?\nendmodule',text,re.S).group()
    assert graph(deployed)==graph(original), 'Frozen layer configuration changed'
    for name in ['shared_mac','shared_line','center_div','source_stats']:
        assert module(deployed,name)==module(original,name), 'Arithmetic changed: '+name
    quant=module(original,'shared_quant')
    quant=quant.replace('input [95:0] accum','input [191:0] accum').replace('input [35:0] skip_codes','input [71:0] skip_codes')
    quant=quant.replace('input [83:0] main_mul,input [191:0] dynamic_bias','input [167:0] main_mul,input [383:0] dynamic_bias')
    quant=quant.replace('output reg [63:0] codes','output reg [127:0] codes').replace('[0:3]','[0:7]').replace('j<4','j<8')
    actual_quant=module(deployed,'shared_quant')
    for lane in range(2):
        declaration=f'\n (* syn_use_dsp="no" *) wire signed [33:0] skip_logic{lane}=$signed(skip_codes[{lane*9}+:9])*$signed(skip_mul);'
        assert actual_quant.count(declaration)==1, 'Unexpected residual multiplier expression'
        actual_quant=actual_quant.replace(declaration,'')
    actual_quant=actual_quant.replace('if(j==0)ps[j]<=skip_logic0;\n     else if(j==1)ps[j]<=skip_logic1;\n     else ps[j]<=', 'ps[j]<=')
    assert actual_quant==quant, 'Quantization differs beyond lane replication / equivalent DSP placement'

    assert 'rtl/cnn/student_u8/stem_packed_weights.mem' in deployed
    from generate_u8_packed_weights import packed_weights
    assert (R/'rtl/cnn/student_u8/stem_packed_weights.mem').read_text()==packed_weights(N/'mem/shared_weights.mem'), 'Invalid stem weight permutation'

    dma=(R/'rtl/accel/artflow_cnn_dma.v').read_text(encoding='utf-8')
    assert 'student_u8 #(' in dma and "? src : SCRATCH+32'h00200000)" in dma
    assert 'rtl/cnn/s8_shared_flat.v' not in sources, 'Old S8 still active'
    manifest=json.loads((N/'PACKAGE_SHA256.json').read_text(encoding='utf-8'))
    for f in ['student_u8_flat.v','architecture.json','golden.py',*[p.relative_to(N).as_posix() for p in (N/'reference').rglob('*') if p.is_file() and '__pycache__' not in p.parts]]:
        assert sha(N/f)==manifest[f], 'Frozen U8 input changed: '+f
    # Allow exactly one additional PLL output and its clock-domain constraint.
    # Existing DDR/camera/HDMI/CPU clocks, pins and timing exceptions stay exact.
    for f in ['ArtFlow.peri.xml','ArtFlow.sdc']:
        old=subprocess.check_output(['git','show','5c2218c:'+f],cwd=R).decode()
        now=(R/f).read_bytes().decode()
        if f.endswith('.xml'):
            addition='            <efxpt:comp_output_clock name="cnn_clk" number="1" out_divider="14" is_dyn_phase="false" phase_setting="0" is_inverted="false" conn_type="gclk"/>\r\n'
            expected=old.replace('            <efxpt:comp_output_clock name="core_clk"',addition+'            <efxpt:comp_output_clock name="core_clk"')
        else:
            expected=old.replace('create_clock -period 10.000 -name core_clk','create_clock -period 7.000 -name cnn_clk [get_ports {cnn_clk}]\r\ncreate_clock -period 10.000 -name core_clk')
            expected=expected.replace('-group {core_clk} -group','-group {core_clk} -group {cnn_clk} -group')
        assert now==expected,'Unexpected board configuration change: '+f
    snap=R/'work/implementation_source_sha256.json'
    if a.snapshot:snap.write_text(json.dumps(sources,indent=2)+'\n')
    if a.check_snapshot:assert json.loads(snap.read_text(encoding='utf-8'))==sources,'Stale implementation'
    print('U8 PROJECT PASS:',len(sources),'inputs; frozen U8 V2 model; dedicated 142.857 MHz CNN, original board clocks/pins')
if __name__=='__main__':main()
