"""Package a reproducible v07 board-test candidate; never claim board acceptance."""
from pathlib import Path
import hashlib,json,re,shutil
from check_project_v05 import implementation_sources,check_firmware
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    check_firmware()
    source=implementation_sources()
    assert source==json.loads((ROOT/'work/implementation_source_sha256.json').read_text())
    implementation=json.loads((ROOT/'work/implementation_summary.json').read_text())
    assert implementation['status']=='PASS'
    for name,digest in implementation['sha256'].items():assert sha(ROOT/name)==digest,name
    ui=json.loads((ROOT/'work/ui_cdc_summary.json').read_text())
    assert ui['status']=='PASS' and any(p['chain']=='process' for p in ui['paths'])
    for name,digest in ui['sha256'].items():assert sha(ROOT/name)==digest,name
    regression=json.loads((ROOT/'work/v07/regression/summary.json').read_text())
    assert regression['status'] in ('PASS','PASS_WITH_TOOL_LIMITATIONS') and regression['full'] and not regression['system_only']
    for name,digest in regression['source_sha256'].items():assert sha(ROOT/name)==digest,name
    for name,digest in regression['evidence_sha256'].items():assert sha(ROOT/'work/v07/regression'/name)==digest,name
    assert any(t['name']=='dma_960x540_fault0' and t['status']=='PASS' for t in regression['tests'])
    assert all(t['status'] in ('PASS','EMITTED_WITH_EXIT_FAULT') for t in regression['tests'])
    tests=json.loads((ROOT/'outputs/firmware/host_tests.json').read_text())
    assert all(t['passed'] for t in tests)
    for name,digest in json.loads((ROOT/'outputs/firmware/host_test_source_sha256.json').read_text()).items():assert sha(ROOT/name)==digest,name
    cpu=json.loads((ROOT/'work/v07/soc_questa/summary.json').read_text())
    for name,digest in cpu['source_sha256'].items():assert sha(ROOT/name)==digest,name
    out=ROOT/'outputs/v07';out.mkdir(parents=True,exist_ok=True)
    for ext in ('bit','hex'):
        p=ROOT/'work/efinity_out'/('ArtFlow.'+ext)
        shutil.copyfile(p,out/('ArtFlow_v07.'+ext))
        shutil.copyfile(p,ROOT/'outflow'/('ArtFlow.'+ext))
    records=['work/implementation_summary.json','work/implementation_source_sha256.json',
             'work/video_cdc_summary.json','work/ui_cdc_summary.json',
             'work/v07/regression/summary.json','work/v07/regression/system.log',
             'work/v07/regression/dma_960x540_fault0.log','work/v07/regression/control.log',
             'work/efinity_out/ArtFlow.map.rpt','work/efinity_out/ArtFlow.timing.rpt',
             'outputs/firmware/build_manifest.json','outputs/firmware/host_tests.json',
             'outputs/firmware/host_test_source_sha256.json','work/v07/soc_questa/summary.json',
             'doc/v07_notes.md']
    # Include the current executed tests; historical tool probes stay in work/.
    records+=['work/v07/regression/'+t['name']+'.log' for t in regression['tests']
              if (ROOT/'work/v07/regression'/(t['name']+'.log')).is_file()]
    for name in records:
        dest=out/'evidence'/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,dest)
    report=(ROOT/'work/efinity_out/ArtFlow.map.rpt').read_text()
    resources={k:int(v) for k,v in re.findall(r'^(EFX_\w+)\s*:\s*(\d+)\s*$',report,re.M)}
    manifest=dict(version='v07',status='READY_FOR_BOARD_TEST',board_verified=False,git_committed=False,
        description='960x540 DDR -> 480x270 rounded box -> identity -> half-pixel bilinear -> DDR styled pool',
        source_sha256=source,minimum_slack_ns=implementation['minimum_slack_ns'],resources=resources,
        rtl_regression_status=regression['status'],tool_limitations=regression['tool_limitations'],
        production_cpu_irq_simulation=cpu['status'],
        production_cpu_irq_note='See evidence/work/v07/soc_questa/summary.json; rerun tools/run_v07_soc.py in a working Questa environment or verify on board',
        network_integrated=False,
        files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file() and p.name!='manifest.json'})
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('V07 BOARD-TEST CANDIDATE PACKAGED:',out)
    print('Board and production CPU IRQ acceptance remain pending. No Git commit.')
if __name__=='__main__':main()
