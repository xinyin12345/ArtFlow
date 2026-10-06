"""Collect current evidence and a self-contained source package; fail if unverified.

Run after the final regression and Efinity build. The optional --delivery-dir
receives delivery copies only; the primary source/evidence stays in this project.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'work/regression_final'
DOC=ROOT/'doc/verification'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def record(p):
    data=p.read_bytes()
    result=dict(path=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(data).hexdigest())
    if p.suffix.lower() in ('.v','.sv','.vh','.svh','.py','.ps1','.tcl','.do','.xml','.sdc','.md','.txt','.json','.log','.rpt','.mem','.memh'):
        result['lf_sha256']=hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()
    return result

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--delivery-dir',type=Path);args=parser.parse_args()
    summary=json.loads((RUN/'summary.json').read_text(encoding='utf-8'))
    implementation=json.loads((ROOT/'work/implementation_summary.json').read_text(encoding='utf-8'))
    cdc=json.loads((ROOT/'work/video_cdc_summary.json').read_text(encoding='utf-8'))
    if any(s['status']!='PASS' for s in (summary,implementation,cdc)):raise ValueError('Verification incomplete')
    for name,value in json.loads((RUN/'source_sha256.json').read_text()).items():
        if sha(ROOT/name)!=value:raise ValueError('RTL/testbench changed since regression: '+name)
    for name,value in implementation['sha256'].items():
        if sha(ROOT/name)!=value:raise ValueError('Implementation changed: '+name)
    for name,value in cdc['sha256'].items():
        if sha(ROOT/name)!=value:raise ValueError('CDC evidence changed: '+name)
    baseline=json.loads((ROOT/'doc/baseline_v03/source_sha256.json').read_text())
    for name,value in baseline.items():
        if sha(ROOT.parent/'v03'/name)!=value:raise ValueError('v03 baseline was changed: '+name)
    DOC.mkdir(exist_ok=True)
    for src,name in [(RUN/'summary.json','regression_summary.json'),(RUN/'source_sha256.json','regression_source_sha256.json'),
                     (RUN/'config.json','board_config.json'),(ROOT/'work/implementation_summary.json','implementation_summary.json'),
                     (ROOT/'work/video_cdc_summary.json','cdc_summary.json'),(ROOT/'work/efinity_compile.log','efinity_compile.log'),
                     (ROOT/'work/efinity_sta_tclsh.log','efinity_cdc.log')]:
        shutil.copyfile(src,DOC/name)
    for name in ['ArtFlow.place.rpt','ArtFlow.timing.rpt','ArtFlow.video_bus_skew.rpt','ArtFlow.video_bus_delay.rpt']:
        shutil.copyfile(ROOT/'work/efinity_out'/name,DOC/name)
    logs=DOC/'logs';logs.mkdir(exist_ok=True)
    evidence=[];case_rows=[]
    for test in summary['tests']:
        log=RUN/(test['name']+'.log')
        if log.exists():
            shutil.copyfile(log,logs/log.name)
            lines=log.read_text(encoding='utf-8').splitlines()
            evidence.extend(['\n## '+test['name']]+[s for s in lines if any(x in s for x in ['FRAME ','COUNTERS ','SCHEDULER ',' PASS','Fatal:','Time: '])])
        case_rows.append('| '+test['name']+' | '+('预期错误拒绝' if test.get('expected_failure') else '正向')+' | '+test['status']+' | '+str(test.get('seconds',''))+' |')
    (DOC/'regression_evidence.log').write_text('\n'.join(evidence)+'\n',encoding='utf-8')
    (ROOT/'doc/case_list.md').write_text('# v04 实际用例列表\n\n由最终 summary.json 生成。负向 PASS 表示指定错误成功被检测。\n\n| 用例 | 类型 | 结果 | 墙钟秒 |\n|---|---|---|---:|\n'+'\n'.join(case_rows)+'\n',encoding='utf-8')
    # The capture file named full is the last full-resolution case (30 fps).
    out=ROOT/'outputs';out.mkdir(exist_ok=True)
    shutil.copyfile(RUN/'full_cap.png',out/'v04_dual_window_capture.png')
    shutil.copyfile(ROOT/'work/efinity_out/ArtFlow.bit',out/'ArtFlow_v04.bit')
    shutil.copyfile(ROOT/'work/efinity_out/ArtFlow.hex',out/'ArtFlow_v04.hex')
    (out/'hardware_status.json').write_text(json.dumps(dict(status='NOT_RUN',required_seconds=1800,
       reason='No board programming or physical HDMI capture performed; RTL endurance is separate.'),indent=2)+'\n')
    source_paths=[p for p in ROOT.rglob('*') if p.is_file() and p.relative_to(ROOT).parts[0] not in ('work','outputs','doc','.git')]
    source_paths += [p for p in (ROOT/'doc').glob('*.md')]
    ev_paths=[p for p in DOC.rglob('*') if p.is_file()]
    manifest=dict(version='v04',sources=[record(p) for p in sorted(source_paths)],
       evidence=[record(p) for p in sorted(ev_paths)],
       generated=[record(ROOT/'work/efinity_out'/n) for n in ['ArtFlow.bit','ArtFlow.hex']])
    (ROOT/'doc/verified_files_sha256.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    package=out/'ArtFlow_v04_source_and_evidence.zip'
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(ROOT.rglob('*')):
            if p.is_file() and p.relative_to(ROOT).parts[0] not in ('work','outputs','.git') and '__pycache__' not in p.parts:
                z.write(p,'ArtFlow_v04/'+p.relative_to(ROOT).as_posix())
    if args.delivery_dir:
        args.delivery_dir.mkdir(parents=True,exist_ok=True)
        for p in out.iterdir():
            if p.is_file():shutil.copyfile(p,args.delivery_dir/p.name)
    print('PACKAGE PASS: '+str(len(summary['tests']))+' checks; v03 unchanged; '+str(package))

if __name__=='__main__':main()
