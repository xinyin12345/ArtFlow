"""Gate normal timing as well as flow exit status; never use CDC-only STA here."""
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]

def parse_timing(body):
    if 'SDC Filename: ArtFlow.sdc' not in body:
        raise ValueError('Normal ArtFlow.sdc timing report required')
    groups={}
    for name,end in [('Setup (Max)','Hold (Min)'),('Hold (Min)','NOTE:')]:
        block=body.split(name+' Clock Relationship',1)[1].split(end,1)[0]
        rows=re.findall(r'^\s*(\S+)\s+(\S+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\(R-R\)',block,re.M)
        if not rows or any(float(r[3])<0 for r in rows):
            raise ValueError('Missing/negative '+name+' slack')
        for clk in ['core_clk','hdmi_tx_slow_clk','i_mipi_rx_pclk']:
            if not any(r[0]==clk and r[1]==clk for r in rows):
                raise ValueError('Missing active clock '+clk)
        groups[name]=min(float(r[3]) for r in rows)
    return groups

def main():
    out=ROOT/'work/efinity_out'
    report=out/'ArtFlow.timing.rpt'
    values=parse_timing(report.read_text(encoding='utf-8'))
    cdc=json.loads((ROOT/'work/video_cdc_summary.json').read_text(encoding='utf-8'))
    if cdc['status']!='PASS':raise ValueError('CDC not passed')
    for name in ['ArtFlow.bit','ArtFlow.hex']:
        if not (out/name).is_file() or (out/name).stat().st_size==0:
            raise ValueError('Missing bitstream '+name)
    paths=[report,out/'ArtFlow.bit',out/'ArtFlow.hex']
    result=dict(status='PASS',minimum_slack_ns=values,
                sha256={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths})
    (ROOT/'work/implementation_summary.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('IMPLEMENTATION PASS: normal timing, CDC and bitstreams; '+str(values))

if __name__=='__main__':main()
