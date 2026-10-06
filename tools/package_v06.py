"""Package v06 only after current RTL, inherited regression, chain and implementation pass."""
from pathlib import Path
import hashlib,json,shutil,zipfile
from check_project_v06 import check,check_baseline
from run_v06 import pixel_check
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def validate_run(directory):
    s=read(directory/'summary.json')
    if s['status']!='PASS':raise ValueError('Regression not PASS: '+str(directory))
    for name,digest in s.get('source_sha256',{}).items():
        if sha(ROOT/name)!=digest:raise ValueError('Regression source changed: '+name)
    for name,digest in s.get('evidence_sha256',{}).items():
        if sha(directory/name)!=digest:raise ValueError('Regression evidence changed: '+name)
    return s
def main():
    sources,_=check();check_baseline(required=True)
    if sources!=read(ROOT/'work/implementation_source_sha256.json'):raise ValueError('Stale implementation')
    run=ROOT/'work/regression_v06';s=validate_run(run)
    if not s.get('full'):raise ValueError('Full inherited regression is required')
    if pixel_check(run/'osd_pixels.hex')!=1728000:raise ValueError('Incomplete OSD pixel evidence')
    validate_run(ROOT/'work/chain_v06')
    inherited=read(run/'inherited/summary.json')
    if inherited['status']!='PASS' or not inherited['scope']['full_video']:raise ValueError('Inherited run incomplete')
    for name,digest in read(run/'inherited/source_sha256.json').items():
        if sha(ROOT/name)!=digest:raise ValueError('Inherited source changed: '+name)
    video=validate_run(run/'inherited/video')
    if len(video['tests'])!=72 or any(t['status']!='PASS' for t in video['tests']):raise ValueError('Expected all 72 inherited checks')
    for name in ('implementation_summary.json','video_cdc_summary.json','ui_cdc_summary.json'):
        data=read(ROOT/'work'/name)
        if data['status']!='PASS':raise ValueError(name+' not PASS')
        for p,digest in data['sha256'].items():
            if sha(ROOT/p)!=digest:raise ValueError('Stale implementation evidence: '+p)
    # Firmware host test source/evidence format is checked by its own runner;
    # require the full five-group fresh result and retain it in the package.
    host=read(ROOT/'outputs/firmware/host_tests.json')
    if len(host)!=5 or not all(t['passed'] for t in host):raise ValueError('Host firmware tests not PASS')
    for name,digest in read(ROOT/'outputs/firmware/host_test_source_sha256.json').items():
        if sha(ROOT/name)!=digest:raise ValueError('Host firmware source changed: '+name)
    evidence=ROOT/'doc/verification';evidence.mkdir(parents=True,exist_ok=True)
    def copy(src,dst):dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    for directory,label in [(run,'v06'),(ROOT/'work/chain_v06','chain'),(run/'inherited','inherited'),(run/'inherited/video','video')]:
        for p in directory.iterdir():
            if p.is_file() and p.suffix in ('.json','.log'):copy(p,evidence/label/p.name)
        for name in read(directory/'summary.json').get('evidence_sha256',{}):
            copy(directory/name,evidence/label/name)
    copy(run/'osd_pixels.hex',evidence/'v06/osd_pixels.hex')
    for name in ('implementation_summary.json','implementation_source_sha256.json','video_cdc_summary.json','ui_cdc_summary.json','ui_cdc.log','efinity_compile.log','efinity_sta_tclsh.log'):
        copy(ROOT/'work'/name,evidence/name)
    for name in ('ArtFlow.timing.rpt','ArtFlow.place.rpt','ArtFlow.pinout.rpt','ArtFlow.map.rpt','ArtFlow.video_bus_skew.rpt','ArtFlow.video_bus_delay.rpt','ArtFlow.warn.log'):
        copy(ROOT/'work/efinity_out'/name,evidence/name)
    for p in (ROOT/'work/efinity_out').glob('ArtFlow.ui_*.rpt'):copy(p,evidence/p.name)
    for name in ('video_cdc_gate_tests.log','implementation_gate_tests.log'):
        if (ROOT/'work'/name).is_file():copy(ROOT/'work'/name,evidence/name)
    gates=read(ROOT/'work/gate_tests/summary.json')
    if gates['status']!='PASS' or len(gates['tests'])!=7:raise ValueError('v06 gate self-tests incomplete')
    copy(ROOT/'work/gate_tests/summary.json',evidence/'gate_tests.json')
    for ext in ('bit','hex'):copy(ROOT/f'work/efinity_out/ArtFlow.{ext}',ROOT/f'outputs/ArtFlow_v06.{ext}')
    paths=[]
    for directory in ('rtl','ip','firmware','sim','tools','inputs','doc'):
        paths += [p for p in (ROOT/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name!='verified_files_sha256.json']
    paths += [ROOT/n for n in ('ArtFlow.xml','ArtFlow.peri.xml','ArtFlow.sdc','README_CODEX.md','yuvpattern_mif.memh','.gitignore')]
    paths += [p for p in (ROOT/'outputs').rglob('*') if p.is_file() and p.suffix!='.zip']
    manifest=ROOT/'doc/verified_files_sha256.json'
    manifest.write_text(json.dumps(dict(version='v06',status='PASS',files={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(set(paths))}),indent=2)+'\n')
    archive=ROOT/'outputs/ArtFlow_v06_project.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(set(paths+[manifest])):z.write(p,'ArtFlow_v06/'+p.relative_to(ROOT).as_posix())
    print('V06 PACKAGE PASS',archive,sha(archive))
if __name__=='__main__':main()
