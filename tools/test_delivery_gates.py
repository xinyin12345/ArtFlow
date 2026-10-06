"""Isolated fixtures for delivery gate; creates no EDA processes or project artifacts."""
import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import time
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT/'tools'))
import check_implementation as implementation
import package_v05 as package
from run_v04 import required_full_results
from v04_config import load_config

CONFIG = load_config()
RESULTS = []


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2)+'\n')


def read_json(path):
    return json.loads(path.read_text())


class Fixture:
    def __init__(self, root):
        self.root = root
        self.out = root/'work/efinity_out'
        self.out.mkdir(parents=True)
        self.source = root/'rtl/source.v'
        self.source.parent.mkdir(parents=True)
        self.source.write_text('module fixture; endmodule\n')
        self.snapshot = root/'work/implementation_source_sha256.json'
        write_json(self.snapshot, self.inputs())
        old = time.time_ns()-5_000_000_000
        os.utime(self.snapshot, ns=(old,old))
        rows = '\n'.join(f'{clock} {clock} 10.000 1.000 (R-R)' for clock in
                         ('core_clk','hdmi_tx_slow_clk','i_mipi_rx_pclk'))
        report = 'SDC Filename: ArtFlow.sdc\nSetup (Max) Clock Relationship\n'+rows+'\nHold (Min) Clock Relationship\n'+rows+'\nNOTE:\n'
        (self.out/'ArtFlow.timing.rpt').write_text(report)
        for name in ['ArtFlow.bit','ArtFlow.hex','ArtFlow.place.rpt',
                     'ArtFlow.video_bus_skew.rpt','ArtFlow.video_bus_delay.rpt']:
            (self.out/name).write_text('isolated fixture '+name+'\n')
        (self.out/'ArtFlow.warn.log').write_text('// Efinity Synthesis Started\nfixture\n')
        write_json(root/'work/video_cdc_summary.json',dict(status='PASS',sha256={
            'work/efinity_out/ArtFlow.video_bus_skew.rpt':sha(self.out/'ArtFlow.video_bus_skew.rpt')}))
        write_json(root/'work/implementation_summary.json',dict(status='RUNNING'))
        self.run_implementation()
        write_json(root/'outputs/firmware/host_tests.json',[dict(passed=True)])
        write_json(root/'outputs/firmware/host_test_source_sha256.json',self.inputs())
        for name in ['efinity_compile.log','efinity_sta_tclsh.log','firmware_tests.log',
                     'cdc_gate_tests.log','implementation_gate_tests.log','v04_evidence_tests.log',
                     'delivery_gate_isolated_tests.log']:
            (root/'work'/name).write_text('isolated fixture PASS\n')
        self.video = root/'work/video'
        for group,names in [('control',['tb_sapphire_i2c','tb_bayer_first_pixel','tb_camera_gate',
                                       'tb_artflow_control','control_async_7_11','control_async_11_7']),
                            ('soc',['soc_success','soc_nack']),
                            ('video',sorted(required_full_results(CONFIG)))]:
            run=root/'work'/group
            run.mkdir()
            write_json(run/'source_sha256.json',self.inputs())
            evidence={'source_sha256.json':sha(run/'source_sha256.json')}
            tests=[]
            for name in names:
                log=run/(name+'.log')
                log.write_text('isolated fixture '+name+' PASS\n')
                evidence[log.name]=sha(log)
                item=dict(name=name,status='PASS',log=log.name,log_sha256=sha(log))
                if name=='endurance':item['parameters']={'NGOOD':1000}
                tests.append(item)
            result=dict(status='PASS',tests=tests)
            if group=='video':
                (run/'full_cap.png').write_bytes(b'isolated capture fixture')
                evidence['full_cap.png']=sha(run/'full_cap.png')
                result.update(config=CONFIG,source_sha256=self.inputs(),evidence_sha256=evidence)
            write_json(run/'summary.json',result)

    def inputs(self):
        return {'rtl/source.v':sha(self.source)}

    def run_implementation(self):
        with patch.object(implementation,'ROOT',self.root), \
             patch.object(implementation,'implementation_sources',self.inputs), \
             contextlib.redirect_stdout(io.StringIO()):
            implementation.main()

    def run_package(self):
        args=['package_v05.py','--control-run',str(self.root/'work/control'),
              '--soc-run',str(self.root/'work/soc'),'--video-run',str(self.video)]
        with patch.object(package,'ROOT',self.root), \
             patch.object(package,'OUT',self.root/'outputs'), \
             patch.object(package,'EVIDENCE',self.root/'doc/verification'), \
             patch.object(package,'check_baseline'), patch.object(package,'check_firmware'), \
             patch.object(package,'implementation_sources',self.inputs), \
             patch.object(package,'load_config',return_value=CONFIG), \
             patch.object(sys,'argv',args), contextlib.redirect_stdout(io.StringIO()):
            package.main()

    def change_summary(self,change):
        path=self.video/'summary.json'
        data=read_json(path)
        change(data)
        write_json(path,data)


def run_case(name,operation,expected_error=None):
    with tempfile.TemporaryDirectory(prefix='delivery_gate_',dir=PROJECT/'work') as temp:
        fixture=Fixture(Path(temp))
        try:
            operation(fixture)
        except (ValueError,KeyError,AssertionError) as error:
            if expected_error and expected_error in str(error):
                print(f'PASS {name}: rejected ({error})')
                RESULTS.append((name,True))
                return
            print(f'FAIL {name}: unexpected {type(error).__name__}: {error}')
            RESULTS.append((name,False))
            return
        if expected_error:
            print(f'FAIL {name}: mutation accepted, expected {expected_error!r}')
            RESULTS.append((name,False))
        else:
            print(f'PASS {name}')
            RESULTS.append((name,True))


def mutate_and_package(fixture,change):
    fixture.change_summary(change)
    fixture.run_package()


def outdated(fixture,name):
    target=fixture.out/name
    old=fixture.snapshot.stat().st_mtime_ns-1_000_000_000
    os.utime(target,ns=(old,old))
    fixture.run_implementation()


def changed_inputs(fixture):
    fixture.source.write_text('module changed; endmodule\n')
    fixture.run_implementation()


def newer_snapshot(fixture):
    latest=max((fixture.out/name).stat().st_mtime_ns for name in
               ('ArtFlow.timing.rpt','ArtFlow.bit','ArtFlow.hex'))+1_000_000_000
    os.utime(fixture.snapshot,ns=(latest,latest))
    fixture.run_implementation()


def snapshot_is_bound(fixture):
    summary=read_json(fixture.root/'work/implementation_summary.json')
    assert summary['sha256']['work/implementation_source_sha256.json']==sha(fixture.snapshot)
    fixture.snapshot.write_text(fixture.snapshot.read_text()+' ')
    fixture.run_package()


def altered_log(fixture):
    (fixture.video/'full_30fps.log').write_text('stale or modified PASS log\n')
    fixture.run_package()


def altered_capture(fixture):
    (fixture.video/'full_cap.png').write_bytes(b'stale capture')
    fixture.run_package()


def unbound_capture(fixture):
    fixture.change_summary(lambda data:data['evidence_sha256'].pop('full_cap.png'))
    (fixture.video/'full_cap.png').write_bytes(b'unbound stale capture')
    fixture.run_package()


def test_log_mismatch(data):
    next(t for t in data['tests'] if t['name']=='full_30fps')['log_sha256']='0'*64


print('Isolated delivery gate fixtures; no EDA commands; no production files modified.')
print('Inputs: '+', '.join(f'{name}={sha(PROJECT/"tools"/name)}' for name in
                         ('check_implementation.py','package_v05.py','run_v04.py')))
run_case('valid_current_implementation_and_72_case_package',lambda f:f.run_package())
run_case('changed_implementation_input',changed_inputs,'Implementation inputs changed')
for name in ('ArtFlow.bit','ArtFlow.hex','ArtFlow.timing.rpt'):
    run_case('old_'+name,lambda f,name=name:outdated(f,name),'Output predates')
run_case('rewritten_snapshot_cannot_sign_old_outputs',newer_snapshot,'Output predates')
run_case('snapshot_bytes_bound_in_implementation_summary',snapshot_is_bound,'Evidence no longer matches work/implementation_source_sha256.json')
run_case('missing_video_check_case',lambda f:mutate_and_package(f,lambda d:d['tests'].__setitem__(slice(None),[t for t in d['tests'] if t['name']!='check_full_30fps'])),'Missing/extra full video')
run_case('duplicate_video_case',lambda f:mutate_and_package(f,lambda d:d['tests'].append(copy.deepcopy(d['tests'][0]))),'Duplicate/failed test')
run_case('failed_video_case',lambda f:mutate_and_package(f,lambda d:d['tests'][0].__setitem__('status','FAIL')),'Duplicate/failed test')
run_case('short_endurance',lambda f:mutate_and_package(f,lambda d:next(t for t in d['tests'] if t['name']=='endurance')['parameters'].__setitem__('NGOOD',999)),'Video endurance')
run_case('summary_source_binding_mismatch',lambda f:mutate_and_package(f,lambda d:d['source_sha256'].__setitem__('rtl/source.v','0'*64)),'Video summary input binding mismatch')
run_case('changed_test_log',altered_log,'Changed video evidence: full_30fps.log')
run_case('test_record_log_digest_mismatch',lambda f:mutate_and_package(f,test_log_mismatch),'Video test log binding mismatch')
run_case('running_summary_rejected',lambda f:mutate_and_package(f,lambda d:d.__setitem__('status','RUNNING')),'Regression failed: video')
run_case('changed_bound_capture',altered_capture,'Changed video evidence: full_cap.png')
run_case('missing_capture_binding',unbound_capture,'capture')
print(f'RESULT {sum(ok for _,ok in RESULTS)}/{len(RESULTS)} passed')
sys.exit(any(not ok for _,ok in RESULTS))
