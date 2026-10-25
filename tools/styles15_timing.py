import re
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
