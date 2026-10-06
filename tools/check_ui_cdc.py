"""Verify that every new synchronizer second stage is present, timed and positive."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def main():
    (ROOT/'work/ui_cdc_summary.json').write_text('{"status":"RUNNING"}\n')
    result=[];files=['tools/check_ui_cdc.tcl','tools/check_ui_cdc.py','work/ui_cdc.log',
        'ArtFlow.sdc','rtl/video/artflow_button.v','rtl/video/artflow_fps.v',
        'work/implementation_source_sha256.json','work/efinity_out/ArtFlow.vdb',
        'work/efinity_out/ArtFlow.place','work/efinity_out/ArtFlow.troutingtraces']
    log=(ROOT/'work/ui_cdc.log').read_text(encoding='utf-16')
    # Existing launcher emits this even for STA with encryption disabled.
    checked_log=log.replace('WARNING: cannot find correct IV value','')
    if re.search(r'WARNING|ERROR|Failed to run command',checked_log):raise ValueError('UI CDC STA warning/error')
    if len(re.findall(r'UI_CDC_ENDPOINT \S+ count=1',log))!=6:raise ValueError('Missing UI CDC endpoints')
    for tag in ('mode','osd','capture'):
        for kind in ('setup','hold'):
            name=f'work/efinity_out/ArtFlow.ui_{tag}_{kind}.rpt';files.append(name)
            text=(ROOT/name).read_text()
            if (ROOT/name).stat().st_mtime_ns < (ROOT/'work/implementation_source_sha256.json').stat().st_mtime_ns:
                raise ValueError('UI CDC report predates implementation: '+name)
            head,tail={'mode':('u_ui/u_mode_key/key_meta','u_ui/u_mode_key/key_sync'),
                       'osd':('u_ui/u_osd_key/key_meta','u_ui/u_osd_key/key_sync'),
                       'capture':('u_ui/u_fps/cap_meta','u_ui/u_fps/cap_sync')}[tag]
            if not re.search(r'Path Start\s*:\s*'+re.escape(head+'~FF|CLK'),text) or not re.search(r'Path End\s*:\s*'+re.escape(tail+'~FF|D'),text):
                raise ValueError('Unexpected synchronizer path: '+name)
            # A missing/false-pathed second stage must not count as a pass.
            values=re.findall(r'Slack\s*:?\s*(-?\d+\.\d+)\s*(?:ns)?',text,re.I)
            if not values or min(map(float,values))<0:raise ValueError('Missing/negative sync path: '+name)
            result.append(dict(chain=tag,kind=kind,min_slack_ns=min(map(float,values))))
    out=dict(status='PASS',paths=result,sha256={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files})
    (ROOT/'work/ui_cdc_summary.json').write_text(json.dumps(out,indent=2)+'\n')
    print('UI CDC PASS',result)
if __name__=='__main__':main()
