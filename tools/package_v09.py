"""Promote only a source-matched, timing-clean, pixel-verified board candidate."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
from check_project_v05 import implementation_sources,check_firmware
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads((R/p).read_text(encoding='utf-8'))
def matches(items,base=R):
    for name,digest in items.items():assert sha(base/name)==digest,'Stale evidence: '+name
def main():
    check_firmware();source=implementation_sources()
    assert source==read('work/implementation_source_sha256.json'),'Implementation changed'
    impl=read('work/implementation_summary.json');assert impl['status']=='PASS';matches(impl['sha256'])
    for path in ['work/video_cdc_summary.json','work/ui_cdc_summary.json']:
        obj=read(path);assert obj['status']=='PASS';matches(obj.get('sha256',{}))
    runs=['sim_32x28_f0','sim_64x44_f0','sim_960x540_f0',*[f'sim_32x28_f{i}' for i in range(1,5)],'system','color','control']
    summaries={}
    for run in runs:
        obj=read(f'work/v09/{run}/summary.json')
        assert obj['status'] in ['PASS','PASS_WITH_TOOL_LIMITATIONS'],run
        matches(obj['source_sha256']);matches(obj['evidence_sha256'],R/f'work/v09/{run}')
        summaries[run]=obj
    assert summaries['sim_64x44_f0']['args']['frames']>=2
    assert summaries['sim_960x540_f0']['args']['width']==960 and summaries['sim_960x540_f0']['args']['height']==540
    assert summaries['sim_960x540_f0']['feature_words']==572280
    assert summaries['system']['pixels']>=6*896
    fw=read('outputs/firmware/host_tests.json');assert all(x['passed'] for x in fw)
    matches(read('outputs/firmware/host_test_source_sha256.json'))
    cpu=read('work/v09/soc_questa/summary.json');assert cpu['status'] in ['PASS','TOOL_BLOCKED'];matches(cpu['source_sha256'])
    baseline=read('doc/v09_baseline.json');matches(baseline['board_inputs']);matches(baseline['network_inputs'])
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==baseline['base_commit'],'Unexpected commit during task'
    assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R,text=True).strip(),'Unexpected staged changes'
    out=R/'outputs/v09';out.mkdir(parents=True,exist_ok=True)
    records=['doc/v09_notes.md','doc/v09_verification_plan.md','doc/v09_verification_results.md','doc/v09_baseline.json',
        'work/implementation_summary.json','work/implementation_source_sha256.json',
        'work/video_cdc_summary.json','work/ui_cdc_summary.json',
        'work/efinity_out/ArtFlow.map.rpt','work/efinity_out/ArtFlow.place.rpt','work/efinity_out/ArtFlow.timing.rpt',
        'outputs/firmware/build_manifest.json','outputs/firmware/host_tests.json',
        'outputs/firmware/host_test_source_sha256.json','work/v09/soc_questa/summary.json']
    for run in runs:
        records+=[p.relative_to(R).as_posix() for p in (R/f'work/v09/{run}').glob('*') if p.suffix in ['.log','.json']]
    for path in records:
        dst=out/'evidence'/path;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/path,dst)
    for ext in ['bit','hex']:
        p=R/f'work/efinity_out/ArtFlow.{ext}';shutil.copyfile(p,out/f'ArtFlow_v09.{ext}')
    report=(R/'work/efinity_out/ArtFlow.map.rpt').read_text()
    resources={k:int(v) for k,v in re.findall(r'^(EFX_\w+)\s*:\s*(\d+)\s*$',report,re.M)}
    sim=(R/'work/v09/sim_960x540_f0/simulation.log').read_text()
    cycles=int(re.search(r'FRAME PASS .*?cycles=(\d+)',sim).group(1))
    pending=['Board image/FPS/stability acceptance','15 fps target at current 100 MHz',
             'Runtime APB weight loading','Board fixed-image injection and DDR checksum readback',
             'Original generic INT32 8x8/24-MAC v08 microbenchmark']
    if cpu['status']!='PASS':pending.append('Production Sapphire CPU/PLIC simulation blocked by WinError 623')
    manifest=dict(version='v09-s8-preview',status='READY_FOR_BOARD_TEST_NOT_MILESTONE_ACCEPTED',
        board_verified=False,git_committed=False,base_commit=baseline['base_commit'],network_integrated=True,
        network='frozen 22-layer W8/A4/S8; 480x270; ROM initialized weights',
        model_sha256=baseline['model_sha256'],core_hz=100000000,
        dma_simulation_cycles=cycles,dma_simulation_ms=cycles/100000,
        dma_simulation_fps_no_camera_display=100000000/cycles,
        simulation_note='Real arithmetic, AXI first-beat latency 12 clocks, 25 percent random channel stalls; isolated DMA test, NOT board FPS',
        minimum_slack_ns=impl['minimum_slack_ns'],resources=resources,
        regression={k:{f:v[f] for f in ['status','tool_limitations']} for k,v in summaries.items()},
        production_cpu_irq_simulation=cpu['status'],pending_acceptance=pending,source_sha256=source)
    note=f'''# v09 上板候选交付

此版本已接入 network 的完整 22 层 S8 风格网络，Git 未提交。不是原计划 v08/v09 全部验收完成。

- 下载：`ArtFlow_v09.bit`；原工程 `outflow/ArtFlow.bit` 为相同文件。
- OSD：V09；左原画、右风格结果；CAP/PRC 为实际计数。
- 完整 960×540 RTL：518,400 个最终像素、572,280 次中间特征写回及地址逐比特一致。
- 独立 DMA 仿真：{cycles:,} 周期，100 MHz 下 {cycles/100000:.3f} ms，约 {100000000/cycles:.2f} fps。这不是板级 FPS，也不包含摄像头/显示争用。
- 整机时序：setup {impl['minimum_slack_ns']['Setup (Max)']:+.3f} ns，hold {impl['minimum_slack_ns']['Hold (Min)']:+.3f} ns。
- ≥15 fps、动态 APB 权重加载、板上固定图/校验和及真实 CPU 验收仍待完成。当前权重随位流加载。
- 串口 115200 8N1，`status` 检查 done/irq 增长、error=0。回退镜像在原工程 `outputs/v07/ArtFlow_v07.bit`。

详细说明：`evidence/doc/v09_notes.md`。全部交付文件 SHA-256、工具限制及验收边界见 `manifest.json`。
'''
    (out/'README.md').write_text(note,encoding='utf-8')
    manifest['files']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file() and p.name!='manifest.json'}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Promotion happens only after every gate above has passed.
    for ext in ['bit','hex']:
        shutil.copyfile(out/f'ArtFlow_v09.{ext}',R/f'outflow/ArtFlow.{ext}')
        assert sha(out/f'ArtFlow_v09.{ext}')==sha(R/f'outflow/ArtFlow.{ext}')
    print(note)
if __name__=='__main__':main()
