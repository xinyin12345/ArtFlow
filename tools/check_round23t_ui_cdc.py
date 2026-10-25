"""Verify that every new synchronizer second stage is present, timed and positive."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def main():
    (ROOT/'work/styles15/ui_cdc_summary.json').write_text('{"status":"RUNNING"}\n')
    result=[];files=['tools/check_ui_cdc.tcl','tools/check_round23t_ui_cdc.py','work/styles15/ui_cdc.log',
        'ArtFlow.sdc','rtl/video/artflow_button.v','rtl/video/artflow_fps.v',
        'work/styles15/implementation_source_sha256.json','work/styles15/out/ArtFlow.vdb',
        'work/styles15/out/ArtFlow.place','work/styles15/out/ArtFlow.troutingtraces']
    log=(ROOT/'work/styles15/ui_cdc.log').read_text(encoding='utf-8')
    # Existing launcher emits this even for STA with encryption disabled.
    checked_log=log.replace('WARNING: cannot find correct IV value','')
    if re.search(r'WARNING|ERROR|Failed to run command',checked_log):raise ValueError('UI CDC STA warning/error')
    if len(re.findall(r'UI_CDC_ENDPOINT \S+ count=1',log))!=34:raise ValueError('Missing UI CDC endpoints')
    for tag in ('layout_bit0','layout_bit1','style','flash','mode','osd','capture','process','diag_vs','diag_raw','diag_bin','csi_core_1','csi_core_2','csi_byte_1','csi_byte_2','csi_pixel_1','csi_pixel_2'):
        for kind in ('setup','hold'):
            name=f'work/styles15/out/ArtFlow.ui_{tag}_{kind}.rpt';files.append(name)
            text=(ROOT/name).read_text()
            if (ROOT/name).stat().st_mtime_ns < (ROOT/'work/styles15/implementation_source_sha256.json').stat().st_mtime_ns:
                raise ValueError('UI CDC report predates implementation: '+name)
            head,tail={**{f'layout_bit{i}':(f'u_video_pipe/u_store/layout_meta[{i}]',f'u_video_pipe/u_store/layout_sync[{i}]') for i in range(2)},
                       'style':('u_video_pipe/u_accel_dma/styles.key_filter/key_meta','u_video_pipe/u_accel_dma/styles.key_filter/key_sync'),
                       'flash':('u_video_pipe/u_accel_dma/styles.banks/reader/miso_meta','u_video_pipe/u_accel_dma/styles.banks/reader/miso_sync'),
                       'mode':('u_ui/u_mode_key/key_meta','u_ui/u_mode_key/key_sync'),
                       'osd':('u_ui/u_osd_key/key_meta','u_ui/u_osd_key/key_sync'),
                       'capture':('u_ui/u_fps/cap_meta','u_ui/u_fps/cap_sync'),
                       'process':('u_process_fps/cap_meta','u_process_fps/cap_sync'),
                       **{'csi_core_1': ('u_csi_reset/core_release[0]', 'u_csi_reset/core_release[1]'), 'csi_core_2': ('u_csi_reset/core_release[1]', 'csi_reset_core_n'), 'csi_byte_1': ('u_csi_reset/byte_release[0]', 'u_csi_reset/byte_release[1]'), 'csi_byte_2': ('u_csi_reset/byte_release[1]', 'csi_reset_byte_n'), 'csi_pixel_1': ('u_csi_reset/pixel_release[0]', 'u_csi_reset/pixel_release[1]'), 'csi_pixel_2': ('u_csi_reset/pixel_release[1]', 'csi_reset_pixel_n')},
                       **{tag:(f'u_control/diag_meta[{i}]',f'u_control/diag_sync[{i}]') for i,tag in enumerate(('diag_vs','diag_raw','diag_bin'))}}[tag]
            if not re.search(r'Path Start\s*:\s*'+re.escape(head+'~FF|CLK'),text) or not re.search(r'Path End\s*:\s*'+re.escape(tail+'~FF|D'),text):
                raise ValueError('Unexpected synchronizer path: '+name)
            # A missing/false-pathed second stage must not count as a pass.
            values=re.findall(r'Slack\s*:?\s*(-?\d+\.\d+)\s*(?:ns)?',text,re.I)
            if not values or min(map(float,values))<0:raise ValueError('Missing/negative sync path: '+name)
            result.append(dict(chain=tag,kind=kind,min_slack_ns=min(map(float,values))))
    out=dict(status='PASS',paths=result,sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files})
    (ROOT/'work/styles15/ui_cdc_summary.json').write_text(json.dumps(out,indent=2)+'\n')
    print('UI CDC PASS',result)
if __name__=='__main__':main()
