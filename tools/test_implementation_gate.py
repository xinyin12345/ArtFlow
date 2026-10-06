"""Prove the report gate rejects negative, missing, and audit-only timing."""
from check_implementation import ROOT,parse_timing
import re

def main():
    body=(ROOT/'work/efinity_out/ArtFlow.timing.rpt').read_text(encoding='utf-8')
    assert parse_timing(body)['Setup (Max)'] >= 0
    def negative(section):
        before,after=body.split(section,1)
        after,n=re.subn(r'(^\s*\S+\s+\S+\s+\d+\.\d+\s+)-?\d+\.\d+(\s+\(R-R\))',
                        r'\g<1>-1.000\g<2>',after,count=1,flags=re.M)
        assert n==1
        return before+section+after
    mutations=[negative('Setup (Max) Clock Relationship'),
               negative('Hold (Min) Clock Relationship'),
               body.replace('hdmi_tx_slow_clk','missing_clock'),
               body.replace('SDC Filename: ArtFlow.sdc','SDC Filename: video_cdc_audit.sdc')]
    for text in mutations:
        try:parse_timing(text)
        except ValueError:pass
        else:raise AssertionError('Invalid timing report accepted')
    print('implementation gate: PASS (normal, negative setup/hold, missing clock, audit report)')

if __name__=='__main__':main()
