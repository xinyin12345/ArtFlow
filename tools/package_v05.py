"""Package only matching, passed offline evidence; hardware remains NOT_RUN."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile
from check_project_v05 import check_baseline, check_firmware, implementation_sources
from run_v04 import required_full_results
from v04_config import load_config

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs'
EVIDENCE=ROOT/'doc/verification'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def assert_hashes(records):
    for name,digest in records.items():
        if sha(ROOT/name)!=digest: raise ValueError('Evidence no longer matches '+name)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--control-run',type=Path,default=ROOT/'work/control_final')
    parser.add_argument('--soc-run',type=Path,default=ROOT/'work/soc_final')
    parser.add_argument('--video-run',type=Path,default=ROOT/'work/video_final')
    parser.add_argument('--delivery-dir',type=Path)
    args=parser.parse_args()
    check_baseline(required=True); check_firmware()
    implementation=json.loads((ROOT/'work/implementation_summary.json').read_text())
    cdc=json.loads((ROOT/'work/video_cdc_summary.json').read_text())
    if implementation['status']!='PASS' or cdc['status']!='PASS':
        raise ValueError('Implementation/CDC not passed')
    required_implementation={'work/implementation_source_sha256.json',
        'work/efinity_out/ArtFlow.timing.rpt','work/efinity_out/ArtFlow.bit','work/efinity_out/ArtFlow.hex'}
    if not required_implementation<=implementation['sha256'].keys():
        raise ValueError('Incomplete implementation input/output binding')
    assert_hashes(implementation['sha256']); assert_hashes(cdc['sha256'])
    if implementation_sources()!=json.loads((ROOT/'work/implementation_source_sha256.json').read_text()):
        raise ValueError('Implementation inputs no longer match bitstream')
    host=json.loads((OUT/'firmware/host_tests.json').read_text())
    if not host or not all(case['passed'] for case in host): raise ValueError('Firmware host tests incomplete')
    assert_hashes(json.loads((OUT/'firmware/host_test_source_sha256.json').read_text()))
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    summary={'status':'PASS','hardware_status':'NOT_RUN','groups':{}}
    for group,run in [('control',args.control_run),('soc',args.soc_run),('video',args.video_run)]:
        run=run.resolve()
        result=json.loads((run/'summary.json').read_text())
        if result['status']!='PASS': raise ValueError('Regression failed: '+group)
        tests=result['tests']
        names=[t['name'] for t in tests]
        if len(names)!=len(set(names)) or any(t['status']!='PASS' for t in tests):
            raise ValueError('Duplicate/failed test records: '+group)
        hashes=json.loads((run/'source_sha256.json').read_text())
        assert_hashes(hashes)
        if group=='control':
            names={t['name'] for t in result['tests']}
            required={'tb_sapphire_i2c','tb_bayer_first_pixel','tb_camera_gate','tb_artflow_control',
                      'control_async_7_11','control_async_11_7'}
            if not required<=names: raise ValueError('Missing control/capture scenarios')
        if group=='soc':
            names={t['name'] for t in result['tests']}
            if not {'soc_success','soc_nack'}<=names: raise ValueError('Missing real CPU scenarios')
        if group=='video':
            if result['config']!=load_config(): raise ValueError('Video configuration changed')
            if set(names)!=required_full_results(result['config']):
                raise ValueError('Missing/extra full video regression cases')
            if next(t for t in tests if t['name']=='endurance')['parameters']['NGOOD']<1000:
                raise ValueError('Video endurance must cover at least 1000 output frames')
            if result['source_sha256']!=hashes: raise ValueError('Video summary input binding mismatch')
            if 'full_cap.png' not in result['evidence_sha256']:
                raise ValueError('Missing verified full-size capture hash')
            for name,digest in result['evidence_sha256'].items():
                path=(run/name).resolve()
                if not path.is_relative_to(run) or sha(path)!=digest:
                    raise ValueError('Changed video evidence: '+name)
            for case in tests:
                if case['log_sha256']!=result['evidence_sha256'][case['log']]:
                    raise ValueError('Video test log binding mismatch: '+case['name'])
            checked_captures=set()
            for case in reversed(tests):
                capture=case.get('capture')
                if capture and capture not in checked_captures:
                    if case['capture_sha256']!=result['evidence_sha256'].get(capture):
                        raise ValueError('Video capture binding mismatch: '+capture)
                    checked_captures.add(capture)
        target=EVIDENCE/group;target.mkdir(exist_ok=True)
        for p in run.iterdir():
            if p.is_file() and p.suffix in ('.log','.json','.png'):
                shutil.copyfile(p,target/p.name)
        summary['groups'][group]=result
    summary['groups']['firmware_host']=host
    summary['groups']['implementation']=implementation
    summary['groups']['cdc']=cdc
    (EVIDENCE/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    for name in ['implementation_summary.json','implementation_source_sha256.json','video_cdc_summary.json',
                 'efinity_compile.log','efinity_sta_tclsh.log','firmware_tests.log',
                 'cdc_gate_tests.log','implementation_gate_tests.log','v04_evidence_tests.log',
                 'delivery_gate_isolated_tests.log']:
        shutil.copyfile(ROOT/'work'/name,EVIDENCE/name)
    for name in ['ArtFlow.place.rpt','ArtFlow.timing.rpt','ArtFlow.video_bus_skew.rpt','ArtFlow.video_bus_delay.rpt']:
        shutil.copyfile(ROOT/'work/efinity_out'/name,EVIDENCE/name)
    warnings=(ROOT/'work/efinity_out/ArtFlow.warn.log').read_text(encoding='utf-8')
    final_section=warnings.rfind('// Efinity Synthesis Started')
    if final_section<0: raise ValueError('Missing synthesis warning audit')
    (EVIDENCE/'efinity_warnings_final.log').write_text(warnings[final_section:],encoding='utf-8')
    for extension in ['bit','hex']:
        shutil.copyfile(ROOT/f'work/efinity_out/ArtFlow.{extension}',OUT/f'ArtFlow_v05.{extension}')
    shutil.copyfile(args.video_run/'full_cap.png',OUT/'v05_inherited_video_capture.png')
    (OUT/'hardware_status.json').write_text(json.dumps(dict(status='NOT_RUN',required_soak_seconds=1800,
        reason='No hardware programming, physical UART capture or HDMI observation performed.'),indent=2)+'\n')
    generated={f'work/efinity_out/ArtFlow.{ext}':sha(ROOT/f'work/efinity_out/ArtFlow.{ext}') for ext in ['bit','hex']}
    paths=[p for p in ROOT.rglob('*') if p.is_file() and p.relative_to(ROOT).parts[0] not in ('work','.git','outputs')
           and '__pycache__' not in p.parts and p!=ROOT/'doc/verified_files_sha256.json']
    paths += [p for p in OUT.rglob('*') if p.is_file() and p.suffix!='.zip']
    manifest=dict(version='v05',offline_status='PASS',hardware_status='NOT_RUN',
                  files={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(paths)},generated=generated)
    (ROOT/'doc/verified_files_sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
    package=OUT/'ArtFlow_v05_source_and_evidence.zip'
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(paths+[ROOT/'doc/verified_files_sha256.json']):
            z.write(p,'ArtFlow_v05/'+p.relative_to(ROOT).as_posix())
    if args.delivery_dir:
        args.delivery_dir.mkdir(parents=True,exist_ok=True)
        for p in OUT.iterdir():
            if p.is_file(): shutil.copyfile(p,args.delivery_dir/p.name)
    print('PACKAGE PASS: '+str(package))


if __name__=='__main__': main()
