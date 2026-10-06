"""Post-route CDC gate; normal setup/hold signoff still uses ArtFlow.sdc."""
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'work'
REPORT = WORK / 'efinity_out/ArtFlow.video_bus_skew.rpt'

GROUPS = (
    dict(name='count_meta', bits=32, budget_ns=2.5,
         source='u_video_pipe/u_store/capture_words*[*]~FF|CLK',
         destination='u_video_pipe/u_store/count_meta[*]~FF|D',
         pins={f'u_video_pipe/u_store/count_meta[{n}]~FF|D' for n in range(32)}),
    dict(name='epoch_meta', bits=32, budget_ns=2.5,
         source='u_video_pipe/u_store/display_epoch*[*]~FF|CLK',
         destination='u_video_pipe/u_store/epoch_meta[*]~FF|D',
         pins={f'u_video_pipe/u_store/epoch_meta[{n}]~FF|D' for n in range(32)}),
    dict(name='gain_mailbox', bits=48, budget_ns=20.0,
         source='u_control/mailbox_*[*]~FF|CLK',
         destination='camera_gain_*[*]~FF|D',
         pins={f'camera_gain_{c}[{n}]~FF|D' for c in 'rgb' for n in range(16)}),
)
NUMBER = r'-?\d+(?:\.\d+)?'


def parse_report(body, groups=GROUPS):
    """Identify exact constraint blocks, not a global list of arbitrary delays."""
    header = re.compile(r'^set_bus_skew -from \[get_pins \{([^}]+)\}\] '
                        r'-to \[get_pins \{([^}]+)\}\] (' + NUMBER + r')\s*$', re.M)
    matches = list(header.finditer(body))
    if len(matches) != len(groups):
        raise ValueError(f'Expected {len(groups)} CDC constraint blocks, got {len(matches)}')
    result = {}
    for index, match in enumerate(matches):
        source, destination, requirement = match.groups()
        candidates = [g for g in groups if g['source'] == source and g['destination'] == destination]
        if len(candidates) != 1:
            raise ValueError('Unexpected CDC constraint: ' + match.group())
        group = candidates[0]
        name = group['name']
        if name in result or float(requirement) != group['budget_ns']:
            raise ValueError('Duplicate constraint or changed budget: ' + name)
        block = body[match.end():matches[index+1].start() if index+1 < len(matches) else len(body)]
        count = re.search(r'^Endpoints:\s*(\d+)\s*$', block, re.M)
        if not count:
            raise ValueError('Missing endpoint count: ' + name)
        # Match the exact from/to pair in the summary, including |CLK / |D pins.
        summary_pattern = (r'^\[get_pins \{' + re.escape(source) + r'\}\]\s*\|\s*'
                           r'\[get_pins \{' + re.escape(destination) + r'\}\]\s*\|\s*'
                           r'(Slow|Fast)\s*\|\s*(' + NUMBER + r')\s*\|\s*('
                           + NUMBER + r')\s*\|\s*(' + NUMBER + r')\s*$')
        summaries = re.findall(summary_pattern, body[:matches[0].start()], re.M)
        if len(summaries) != 1:
            raise ValueError('Missing/duplicate skew summary: ' + name)
        corner, requirement, actual, slack = summaries[0]
        if float(requirement) != group['budget_ns'] or float(actual) < 0 or float(slack) < 0:
            raise ValueError('CDC skew violation or changed budget: ' + name)
        if float(actual) > group['budget_ns'] or abs(float(requirement)-float(actual)-float(slack)) > 0.003:
            raise ValueError('Inconsistent skew/slack summary: ' + name)
        result[name] = dict(block=block, endpoints=int(count[1]), corner=corner,
                            skew_ns=float(actual), slack_ns=float(slack))
    if set(result) != {g['name'] for g in groups}:
        raise ValueError('Missing CDC bus')
    return result


def parse_reports(skew_body, slow_body, groups=GROUPS):
    skew, slow = parse_report(skew_body, groups), parse_report(slow_body, groups)
    results = []
    for group in groups:
        name, bits, budget = group['name'], group['bits'], group['budget_ns']
        fast_result, slow_result = skew[name], slow[name]
        # Usually N-1: a unique minimum-delay reference is not compared to
        # itself. With tied minima Efinity can report N, using the two tied
        # pins as each other's references. Prove that case from detail below.
        comparisons = slow_result['endpoints']
        if fast_result['endpoints'] != bits or comparisons not in (bits-1, bits):
            raise ValueError(f'Incorrect CDC endpoint count: {name}')
        block = slow_result['block']
        pins = set(re.findall(r'^(?:Endpoint|Reference) Destination:\s*(\S+)', block, re.M))
        if pins != group['pins']:
            raise ValueError(f'Missing/unexpected slow-corner CDC pins: {name}; '
                             f'missing={sorted(group["pins"]-pins)} extra={sorted(pins-group["pins"])}')
        pairs = re.findall(r'^(Endpoint|Reference) Source:\s*(\S+)[^\n]*\n'
                           r'\1 Destination:\s*(\S+)', block, re.M)
        if len(pairs) != 2*comparisons:
            raise ValueError('Missing source/destination pairs: ' + name)
        for _, source, destination in pairs:
            bit = int(re.search(r'\[(\d+)\]', destination)[1])
            if name == 'gain_mailbox':
                expected = {destination.replace('camera_gain_', 'u_control/mailbox_').replace('|D', '|CLK')}
            else:
                stem = 'capture_words' if name == 'count_meta' else 'display_epoch'
                expected = {f'u_video_pipe/u_store/{stem}_gray[{bit}]~FF|CLK'}
                # Synthesis merges only the unchanged MSB of Gray encoding.
                if bit == 31:
                    expected.add(f'u_video_pipe/u_store/{stem}[31]~FF|CLK')
            if source not in expected:
                raise ValueError(f'Wrong CDC source-to-bit mapping: {source} -> {destination}')
        path_types = re.findall(r'^Path Type:\s*(.+?)\s*$', block, re.M)
        delays = [float(v) for v in re.findall(r'^(?:Endpoint|Reference) Relative Delay:\s*('
                                              + NUMBER + r') ns', block, re.M)]
        data_delays = [float(v) for v in re.findall(r'^\+ Clock To Q \+ Data Path Delay\s*:\s*('
                                                   + NUMBER + r')', block, re.M)]
        if len(path_types) != comparisons or any(p != 'Max at Slow Process Corner' for p in path_types):
            raise ValueError('Missing/non-slow detailed paths: ' + name)
        if len(delays) != 2*comparisons or len(data_delays) != 2*comparisons:
            raise ValueError('Missing CDC relative/data-delay fields: ' + name)
        endpoint_pins = re.findall(r'^Endpoint Destination:\s*(\S+)', block, re.M)
        reference_pins = re.findall(r'^Reference Destination:\s*(\S+)', block, re.M)
        if len(endpoint_pins) != comparisons or len(set(endpoint_pins)) != comparisons:
            raise ValueError('Missing/duplicate CDC endpoint detail: ' + name)
        if len(reference_pins) != comparisons or any(a == b for a, b in zip(endpoint_pins, reference_pins)):
            raise ValueError('Missing/self-referential CDC comparison: ' + name)
        endpoint_delays = [float(v) for v in re.findall(r'^Endpoint Relative Delay:\s*('
                                                       + NUMBER + r') ns', block, re.M)]
        reference_delays = [float(v) for v in re.findall(r'^Reference Relative Delay:\s*('
                                                        + NUMBER + r') ns', block, re.M)]
        if len(endpoint_delays) != comparisons or len(reference_delays) != comparisons:
            raise ValueError('Missing per-role CDC delays: ' + name)
        if comparisons == bits:
            # All N endpoints must be unique and present. Every reference must
            # be an observed endpoint at the same minimum delay (0.001 ns is
            # report precision), with at least two distinct tied reference pins.
            by_pin = dict(zip(endpoint_pins, endpoint_delays))
            minimum = min(endpoint_delays + reference_delays)
            if set(endpoint_pins) != group['pins'] or len(set(reference_pins)) < 2:
                raise ValueError('Extra comparison lacks tied minimum pins: ' + name)
            for pin, delay in zip(reference_pins, reference_delays):
                if abs(delay-minimum) > 0.0011 or abs(by_pin[pin]-delay) > 0.0011:
                    raise ValueError('Extra comparison is not a tied-minimum reference: ' + name)
        detail_slack = [float(v) for v in re.findall(r'^Slack:\s*(' + NUMBER + r') ns', block, re.M)]
        if len(detail_slack) != comparisons or min(detail_slack) < 0:
            raise ValueError('Missing/negative detailed CDC skew slack: ' + name)
        if max(delays) > budget or max(data_delays) > budget or min(data_delays) < 0:
            raise ValueError(f'CDC route exceeds {budget} ns data-delay budget: {name}')
        results.append(dict(name=name, endpoints=bits, budget_ns=budget,
                            slow_comparisons=comparisons,
                            skew_ns=fast_result['skew_ns'], slack_ns=fast_result['slack_ns'],
                            max_relative_delay_ns=max(delays), max_data_delay_ns=max(data_delays)))
    return results


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
    slow = (WORK/'efinity_out/ArtFlow.video_bus_delay.rpt').read_text()
    buses = parse_reports(body, slow)
    files = ['ArtFlow.sdc','rtl/video/rgb_frame_store.v','rtl/control/artflow_control.v',
             'rtl/ArtFlow_top.v','tools/check_video_cdc.py','tools/check_video_cdc.tcl','work/video_cdc_audit.sdc',
             'work/efinity_out/ArtFlow.vdb','work/efinity_out/ArtFlow.place',
             'work/efinity_out/ArtFlow.troutingtraces',
             'work/efinity_out/ArtFlow.video_bus_skew.rpt',
             'work/efinity_out/ArtFlow.video_bus_delay.rpt']
    result = dict(status='PASS', buses=buses, endpoints=[b['endpoints'] for b in buses],
                  skew_ns=[b['skew_ns'] for b in buses], slack_ns=[b['slack_ns'] for b in buses],
                  kind='post-route audit with clock groups omitted',
                  sha256={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files})
    (WORK/'video_cdc_summary.json').write_text(json.dumps(result, indent=2)+'\n')
    print('CDC PASS: 32+32+48 endpoints; ' + '; '.join(
          f'{b["name"]}: skew={b["skew_ns"]}, data={b["max_data_delay_ns"]}, '
          f'budget={b["budget_ns"]} ns' for b in buses))


if __name__ == '__main__':
    if sys.argv[1:] == ['prepare']:
        prepare()
    elif sys.argv[1:] == ['check']:
        check()
    else:
        raise SystemExit('Expected prepare or check')
