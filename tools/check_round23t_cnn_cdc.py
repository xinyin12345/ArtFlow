"""Audit the added CNN FIFO crossings against post-route data-delay bounds."""
from pathlib import Path
import hashlib,json,re,sys
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare():
    (R/'work/styles8/cnn_cdc_summary.json').write_text('{"status":"RUNNING"}\n')
    s=(R/'ArtFlow.sdc').read_text()
    lines=re.findall(r'(?m)^set_clock_groups[^\r\n]*',s)
    assert len(lines)==1
    s=s.replace(lines[0],'# Clock groups omitted ONLY for the CNN CDC route audit')
    (R/'work/styles8/cnn_cdc_audit.sdc').write_text(s)
def check():
    from check_round23t_project import verify as implementation_sources
    snap=R/'work/styles8/implementation_source_sha256.json'
    assert implementation_sources()==json.loads(snap.read_text()),'Implementation inputs changed'
    paths=['ArtFlow.sdc','rtl/accel/artflow_cnn_cdc_fifo.v','candidates/round15_return_ram/artflow_cnn_accel.v',
           'tools/check_round23t_cnn_cdc.py','tools/check_cnn_cdc.tcl','tools/check_al_lease_cdc.tcl','tools/build_styles8.py',
           'work/styles8/implementation_source_sha256.json','work/styles8/cnn_cdc_audit.sdc','work/styles8/cnn_cdc.log',
           'work/styles8/out/ArtFlow.vdb','work/styles8/out/ArtFlow.place','work/styles8/out/ArtFlow.troutingtraces']
    def report(name):
        p=R/('work/styles8/out/ArtFlow.'+name+'.rpt')
        assert p.stat().st_mtime_ns>snap.stat().st_mtime_ns,'Stale report: '+name
        paths.append(p.relative_to(R).as_posix());return p.read_text()
    def detail(s):
        result=[]
        for b in re.split(r'\+\+\+\+ Path \d+ \++',s)[1:]:
            def field(key):
                m=re.search(r'^'+key+r'\s*:\s*(\S+)',b,re.M);assert m,key;return m[1]
            result.append(dict(start=field('Path Start'),end=field('Path End'),
                               delay=float(field('Data Path Delay')),slack=float(field('Slack'))))
        assert result,'Missing timing paths';return result
    prefix='u_video_pipe/u_accel_dma/'
    sizes=dict(jobs=2,events=2,ar=2,aw=2,w=3,r=3,b=2,style_status_fifo=2)
    meta={prefix+f'{f}/{d}gray_meta[{i}]~FF|D' for f,a in sizes.items() for d in 'wr' for i in range(a+1)}
    log=(R/'work/styles8/cnn_cdc.log').read_text(encoding='utf-8')
    assert len(re.findall(r'CNN_CDC_SYNC \S+ count=[34]',log))==32,'Missing synchronizer inventory'
    assert not re.search(r'ERROR|WARNING|Failed to run',log.replace('WARNING: cannot find correct IV value',''))
    sync_count=0
    for f,a in sizes.items():
        for d in 'wr':
            for kind in ['setup','hold']:
                v=detail(report(f'cnn_{f}_{d}_{kind}'))
                want={prefix+f'{f}/{d}gray_sync[{i}]~FF|D' for i in range(a+1)}
                assert len(v)==a+1 and {x['end'] for x in v}==want
                for x in v:
                    assert x['start']==x['end'].replace('_sync','_meta').replace('|D','|CLK')
                    assert x['slack']>=0,'Negative synchronizer timing'
                sync_count+=len(v)
    for i in range(2):
        for kind in ['setup','hold']:
            v=detail(report(f'cnn_reset_{i}_{kind}'))
            assert len(v)==1 and v[0]['start']==prefix+f'reset_cnn[{i}]~FF|CLK'
            assert v[0]['end']==prefix+f'reset_cnn[{i+1}]~FF|D' and v[0]['slack']>=0
            sync_count+=1
    def expand(pin):
        m=re.search(r'\[(\d+):(\d+)\]',pin)
        if not m:return {pin}
        hi,lo=map(int,m.groups())
        return {pin[:m.start()]+f'[{i}]'+pin[m.end():] for i in range(lo,hi+1)}
    lease_meta={prefix+'park_meta~FF|D':(prefix+'park_req~FF|CLK','core_to_cnn'),prefix+'ack_meta~FF|D':(prefix+'park_ack~FF|CLK','cnn_to_core')}
    lease_seen=set()
    for head,tail in [('park_meta','park_sync'),('ack_meta','ack_sync')]:
        for kind in ['setup','hold']:
            v=detail(report('lease_'+head+'_'+kind));assert len(v)==1
            assert v[0]['start']==prefix+head+'~FF|CLK' and v[0]['end']==prefix+tail+'~FF|D' and v[0]['slack']>=0
    crossings=[];all_meta=set();reset_sr=set()
    for direction in ['cnn_to_core','core_to_cnn']:
        inventory=set()
        for row in report(direction+'_cdc').splitlines():
            if not re.match(r'^\s*\d+\s*\|',row):continue
            fields=[v.strip() for v in re.split(r'\s+\|(?=\s)',row.strip())];assert len(fields)==5,row
            _,exception,description,source,dest=fields
            assert exception=='None','Crossing excluded from route audit'
            if dest.endswith('~FF|SR'):
                # Common asynchronous assertion feeds the dedicated three-FF
                # reset-release chain, never a payload or control register.
                assert source=='accel_pready~FF|CLK' and direction=='core_to_cnn'
                assert re.fullmatch(re.escape(prefix)+r'reset_cnn\[[012]\]~FF\|SR',dest),dest
                reset_sr.add(dest)
            elif dest in lease_meta:
                assert (source,direction)==lease_meta[dest],(source,dest,direction)
                assert 'synchronized with ASYNC_REG property' in description
                lease_seen.add(dest)
            elif 'gray_meta' in dest:
                assert 'synchronized with ASYNC_REG property' in description
                assert re.fullmatch(re.escape(prefix)+r'(jobs|events|ar|aw|w|r|b|style_status_fifo)/[wr](gray|bin)\[[\d:]+\]~FF\|CLK',source)
                same_gray=dest.replace('gray_meta','gray').replace('|D','|CLK')
                if source!=same_gray:
                    # Only Gray's unchanged MSB may merge with its binary FF.
                    f=dest[len(prefix):].split('/')[0]
                    assert source==same_gray.replace('gray','bin') and f'[{sizes[f]}]' in dest
            else:
                assert re.fullmatch(r'(?:i\d+/)?'+re.escape(prefix)+r'(jobs|events|ar|aw|w|r|b|style_status_fifo)/storage\[\d+\]\[[\d:]+\]~FF\|CLK',source),source
                assert re.fullmatch(r'u_video_pipe/(?:a_(?:wdata|wstrb|wlast|awaddr|awlen|araddr|arlen)|u_accel_dma/(?:event_data|job|c_rdata|c_rlast|c_rresp|c_bresp|status_data))(?:\[[\d:]+\])?~FF\|D',dest),dest
            inventory.update(expand(dest))
        v=detail(report(direction))
        assert len(v)==len(inventory) and {x['end'] for x in v}==inventory,'Unreported crossing endpoint'
        for x in v:
            if x['end'] in lease_meta:
                assert 0<=x['delay']<=4.5,'Lease first-stage route exceeds audit budget'
            elif x['end'] in meta:
                all_meta.add(x['end']);assert x['delay']<=4.5,'Gray route exceeds one fastest period'
            else:assert 0<=x['delay']<=8.0,'Payload route exceeds synchronized-valid settling budget'
        crossings.append(dict(direction=direction,endpoints=len(v),maximum_data_delay_ns=max(x['delay'] for x in v)))
    assert lease_seen==set(lease_meta),'Missing lease crossings'
    assert all_meta==meta,'Missing Gray bits'
    assert reset_sr=={prefix+f'reset_cnn[{i}]~FF|SR' for i in range(3)}
    result=dict(status='PASS',lease_crossings=sorted(lease_seen),lease_sync_paths=4,gray_endpoints=len(meta),synchronizer_setup_hold_paths=sync_count,
                crossing_groups=crossings,gray_delay_budget_ns=4.5,payload_delay_budget_ns=8,
                note='Clock-group-free route audit; FIFO held payload is a reviewed multi-bit CDC, not independent bit synchronizers',
                sha256={n:sha(R/n) for n in paths})
    (R/'work/styles8/cnn_cdc_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print('CNN CDC PASS:',crossings,'Gray bits',len(meta),'timed synchronizer paths',sync_count)
if __name__=='__main__':
    {'prepare':prepare,'check':check}[sys.argv[1]]()
