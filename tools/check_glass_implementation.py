"""Fail closed on normal STA, routed CDC, fit and current source hashes."""
from pathlib import Path
import json,re
from check_glass_project import R,sha,implementation_sources
from check_implementation import parse_timing
def main():
    w=R/'work/glass_int8';o=w/'efinity_out'
    snap=w/'implementation_source_sha256.json'
    assert implementation_sources()==json.loads(snap.read_text()),'Implementation sources changed'
    timing=parse_timing((o/'ArtFlow.timing.rpt').read_text())
    place=(o/'ArtFlow.place.rpt').read_text()
    resources={}
    for tag,label in [('xlr','XLRs'),('ram10','Memory Blocks'),('dsp','DSP Blocks')]:
        m=re.search(r'^'+label+r':\s*(\d+)\s*/\s*(\d+)',place,re.M);assert m,label
        a,b=map(int,m.groups());assert a<=b;resources[tag]=dict(used=a,available=b)
    for kind in ['video','ui','cnn','style_io']:
        s=json.loads((w/f'{kind}_cdc_summary.json').read_text());assert s['status']=='PASS'
        for name,h in s['sha256'].items():assert sha(R/name)==h,'Stale CDC: '+name
    files=[o/'ArtFlow.bit',o/'ArtFlow.hex',o/'ArtFlow.timing.rpt',o/'ArtFlow.place.rpt']
    for p in files:assert p.is_file() and p.stat().st_size>0 and p.stat().st_mtime_ns>snap.stat().st_mtime_ns,'Stale output: '+p.name
    result=dict(status='PASS',minimum_slack_ns=timing,resources=resources,
        source_snapshot_sha256=sha(snap),sha256={p.relative_to(R).as_posix():sha(p) for p in files})
    (w/'implementation_summary.json').write_text(json.dumps(result,indent=2))
    print('GLASS IMPLEMENTATION PASS',resources,timing)
if __name__=='__main__':main()

