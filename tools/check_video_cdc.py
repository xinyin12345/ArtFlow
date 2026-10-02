"""Post-route CDC gate; normal setup/hold signoff still uses ArtFlow.sdc."""
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work'
REPORT = WORK / 'efinity_out/ArtFlow.video_bus_skew.rpt'


def prepare():
    WORK.mkdir(exist_ok=True)
    (WORK/'video_cdc_summary.json').write_text('{"status":"NOT_RUN"}\n')
    source = (ROOT / 'ArtFlow.sdc').read_text()
    lines = re.findall(r'(?m)^set_clock_groups[^\r\n]*', source)
    if len(lines) != 1 or lines[0].endswith('\\'):
        raise ValueError('Review CDC audit generator after clock-group changes')
    source = source.replace(lines[0], '# Clock groups omitted ONLY for CDC route audit')
    WORK.mkdir(exist_ok=True)
    (WORK/'video_cdc_audit.sdc').write_text('# CDC audit only: NOT normal setup/hold signoff\n' + source)


def check():
    body = REPORT.read_text()
    endpoints = [int(v) for v in re.findall(r'Endpoints:\s*(\d+)', body)]
    rows = re.findall(r'\|\s*(?:Slow|Fast)\s*\|\s*2\.500\s*\|\s*([\d.]+)\s*\|\s*(-?[\d.]+)', body)
    slow = (WORK/'efinity_out/ArtFlow.video_bus_delay.rpt').read_text()
    # -setup reports 31 comparisons per 32-bit bus: the minimum-delay bit is
    # the reference, not its own endpoint. Validate the UNION, not just count.
    for name in ('count_meta','epoch_meta'):
        bits = {int(v) for v in re.findall(r'(?:Endpoint|Reference) Destination:\s*'
                r'u_video_pipe/u_store/' + name + r'\[(\d+)\]~FF\|D', slow)}
        if bits != set(range(32)):
            raise ValueError('Missing slow-corner CDC bits: ' + name)
    delays = [float(v) for v in re.findall(r'(?:Endpoint|Reference) Relative Delay:\s*([\d.]+) ns', slow)]
    if endpoints != [32, 32] or len(rows) != 2 or not delays:
        raise ValueError(f'CDC paths missing: endpoints={endpoints}, rows={len(rows)}, paths={len(delays)}')
    if any(float(slack) < 0 for _, slack in rows) or max(delays) > 2.5:
        raise ValueError('CDC route exceeds 2.5 ns skew/data-delay budget')
    files = ['ArtFlow.sdc','rtl/video/rgb_frame_store.v','work/video_cdc_audit.sdc',
             'work/efinity_out/ArtFlow.vdb','work/efinity_out/ArtFlow.place',
             'work/efinity_out/ArtFlow.troutingtraces',
             'work/efinity_out/ArtFlow.video_bus_skew.rpt',
             'work/efinity_out/ArtFlow.video_bus_delay.rpt']
    result = dict(status='PASS', endpoints=endpoints, skew_ns=[float(a) for a, _ in rows],
                  slack_ns=[float(s) for _, s in rows], max_data_delay_ns=max(delays),
                  budget_ns=2.5, kind='post-route audit with clock groups omitted',
                  sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files})
    (WORK/'video_cdc_summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print('CDC PASS: 32+32 endpoints, skew=' + str(result['skew_ns']) +
          ', max data delay=' + str(max(delays)) + ' ns')


if __name__ == '__main__':
    if sys.argv[1:] == ['prepare']:
        prepare()
    elif sys.argv[1:] == ['check']:
        check()
    else:
        raise SystemExit('Expected prepare or check')
