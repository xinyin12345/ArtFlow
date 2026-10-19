"""Publish the source-matched Student U8 V2 board-preview image after real gates."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
from check_project_v05 import implementation_sources,check_firmware
R=Path(__file__).resolve().parents[1]
N=R/'network/Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60_20261014/XDL1_Student_U8_RTL_OptimizedV2_IntegrationKit_Ti60'
W=R/'work/u8_integration'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads((R/p).read_text(encoding='utf-8'))
def matches(items,base=R):
    for name,digest in items.items():assert sha(base/name)==digest,'Stale evidence: '+name
def main():
    subprocess.check_call([sys.executable,'-B',str(R/'tools/check_project_u8.py'),'--check-snapshot'],cwd=R)
    subprocess.check_call([sys.executable,'-B',str(N/'verify_package.py')],cwd=R)
    check_firmware()
    sources=implementation_sources();assert sources==read('work/implementation_source_sha256.json')
    records={'work/implementation_source_sha256.json','work/efinity_compile.log',
             'work/efinity_out/ArtFlow.map.rpt','work/efinity_out/ArtFlow.place.rpt',
             'work/efinity_out/ArtFlow.timing.rpt','work/efinity_out/ArtFlow.pt.sdc',
             'tools/check_project_u8.py','tools/run_u8.py','tools/run_u8_questa.py',
             'tools/run_u8_system.py','tools/run_u8_optimization_regression.py','tools/package_u8_optimized.py',
             'tools/run_efinity.ps1','doc/u8_integration.md','work/u8_optimization/regression.json',
             'outputs/firmware/build_manifest.json','outputs/firmware/host_tests.json',
             'outputs/firmware/host_test_source_sha256.json'}
    gates={}
    for path in ['work/implementation_summary.json','work/video_cdc_summary.json','work/ui_cdc_summary.json','work/cnn_cdc_summary.json']:
        obj=read(path);assert obj['status']=='PASS',path;matches(obj['sha256']);gates[path]=obj;records.add(path)
        records.update(n for n in obj['sha256'] if Path(n).suffix in ['.rpt','.log','.sdc','.json','.tcl','.py','.ps1'])
    timing=(R/'work/efinity_out/ArtFlow.timing.rpt').read_text()
    assert re.search(r'^cnn_clk\s+cnn_clk\s+7\.000\s+\d+\.\d+',timing,re.M),'CNN not timed at 7 ns'
    assert 'create_clock -period 7.000 -name cnn_clk' in (R/'work/efinity_out/ArtFlow.pt.sdc').read_text()
    cases=['opt_smoke_32x28_c3.5_v1','opt_stress_48x36_c3.7_v1','opt_random_192x108_c3.5_v1',*[f'opt_fault{i}_32x28_c3.5_v0' for i in range(1,5)],'system','opt_full_960x540_c3.5_v1']
    regressions={}
    for name in cases:
        rel='work/u8_integration/'+name
        obj=read(rel+'/summary.json');assert obj['status']=='PASS',name
        matches(obj['source_sha256']);matches(obj['evidence_sha256'],R/rel)
        records.add(rel+'/summary.json');records.update(rel+'/'+n for n in obj['evidence_sha256'])
        regressions[name]=obj
    bridge_rel='work/u8_optimization/bridge_unit'
    bridge=read(bridge_rel+'/summary.json');assert bridge['status']=='PASS'
    matches(bridge['source_sha256']);matches(bridge['evidence_sha256'],R/bridge_rel)
    records.add(bridge_rel+'/summary.json');records.update(bridge_rel+'/'+n for n in bridge['evidence_sha256'])
    records.update(['tools/run_u8_bridge.py','sim/tb_u8_bridge.sv','tools/generate_u8_packed_weights.py','doc/u8_optimization_plan.md',
                    'rtl/cnn/student_u8/student_u8_flat.v','rtl/cnn/student_u8/stem_packed_weights.mem',
                    'rtl/accel/artflow_cnn_bridge.v','rtl/accel/artflow_cnn_resize.v'])
    assert all(x['returncode']==0 for x in read('work/u8_optimization/regression.json'))
    # Reuse unchanged FIFO unit evidence, explicitly marked as previous evidence.
    previous='work/v09_perf/cdc'
    fifo=read(previous+'/summary.json')
    assert fifo['status'] in ['PASS','PASS_WITH_TOOL_LIMITATIONS']
    matches(fifo['source_sha256']);matches(fifo['evidence_sha256'],R/previous)
    records.add(previous+'/summary.json');records.update(previous+'/'+n for n in fifo['evidence_sha256'])
    full=regressions['opt_full_960x540_c3.5_v1']
    assert full['args']['frames']==2 and full['feature_words']==782400
    cycles=full['frame_cycles_100mhz'];assert len(cycles)==2 and min(cycles)>0
    assert regressions['system']['pixels']>=6*896
    logs=(W/'opt_full_960x540_c3.5_v1/simulation.log').read_text()
    traffic=re.search(r'TRAFFIC read_beats=(\d+) write_beats=(\d+)',logs);assert traffic
    read_mbps=int(traffic[1])*1600/sum(cycles);write_mbps=int(traffic[2])*1600/sum(cycles)
    assert read_mbps>=250 and write_mbps>=62.5,'Missing background video traffic'
    assert all(t['passed'] for t in read('outputs/firmware/host_tests.json'))
    matches(read('outputs/firmware/host_test_source_sha256.json'))
    resources={k:int(v) for k,v in re.findall(r'^(EFX_\w+)\s*:\s*(\d+)\s*$',(R/'work/efinity_out/ArtFlow.map.rpt').read_text(),re.M)}
    assert resources['EFX_RAM10']<=256 and resources.get('EFX_DSP48',0)+resources.get('EFX_DSP24',0)+resources.get('EFX_DSP12',0)<=160
    placement=(R/'work/efinity_out/ArtFlow.place.rpt').read_text()
    xlr=int(re.findall(r'XLRs: (\d+) / 60800',placement)[-1]);assert xlr<=60800
    resources['XLR']=xlr
    impl=gates['work/implementation_summary.json'];fps=1e8/max(cycles)
    assert fps>read('outputs/student_u8_v2/manifest.json')['contended_simulation_min_fps'], 'No verified performance improvement'
    baseline=read('outputs/student_u8_v2/manifest.json')
    baseline_summary=read('outputs/student_u8_v2/evidence/work/u8_integration/full_960x540_c3.5_v1/summary.json')
    for key in ['width','height','frames','video_load','cnn_half_ns','stall_pct','rd_lat','seed']:
        assert full['args'][key]==baseline_summary['args'][key], 'Incomparable performance condition: '+key
    oldlog=(R/'outputs/student_u8_v2/evidence/work/u8_integration/full_960x540_c3.5_v1/simulation.log').read_text()
    old_layers=[int(x) for x in re.findall(r'LAYER next=\d+ cycles=(\d+)',oldlog)][:19]
    new_layers=[int(x) for x in re.findall(r'LAYER next=\d+ cycles=(\d+)',logs)][:19]
    assert len(old_layers)==len(new_layers)==19
    bounds=[0,1,5,14,19,20]
    old_edges=[0,*old_layers,baseline_summary['frame_cycles_100mhz'][0]]
    new_edges=[0,*new_layers,cycles[0]]
    stage_names=['预处理＋首层','其余编码器层','残差主体','解码器＋RGB','写入排空＋后处理']
    stage_rows=[]
    for i,label in enumerate(stage_names):
        old_ms=(old_edges[bounds[i+1]]-old_edges[bounds[i]])/1e5
        new_ms=(new_edges[bounds[i+1]]-new_edges[bounds[i]])/1e5
        stage_rows.append(f'| {label} | {old_ms:.3f} | {new_ms:.3f} |')
    comparison='\n'.join(stage_rows)
    gain=(fps/baseline['contended_simulation_min_fps']-1)*100
    report=f"""# Student U8 整机吞吐优化验证结果

状态：READY_FOR_BOARD_TEST。当前原工程已完成同模型吞吐优化；本次没有提交 Git，也没有下载板卡。

| 项目 | 结果 |
|---|---|
| 模型 | 冻结的 19 层 Student U8 Optimized V2；U8/S12 精度 |
| CNN / AXI / CPU | 142.857 / 100 / 100 MHz |
| 模型输入 / 显示结果 | 480×270 / 960×540 |
| 最终 RGB 地址 | 0x01A00000（CNN 第 1 槽） |
| 完整尺寸仿真 | 连续 2 帧；每帧 782,400 次中间写及地址、518,400 个显示像素完全一致 |
| 100 MHz 墙钟周期 | {', '.join(str(x) for x in cycles)} |
| 上述访存条件下最低仿真处理速度 | {fps:.3f} FPS |
| 后台竞争读 / 写带宽 | {read_mbps:.2f} / {write_mbps:.2f} MB/s |
| 正常时序最差 setup / hold | {impl['minimum_slack_ns']['Setup (Max)']:+.3f} / {impl['minimum_slack_ns']['Hold (Min)']:+.3f} ns |
| RAM10 / DSP | {resources['EFX_RAM10']}/256；{resources.get('EFX_DSP48',0)+resources.get('EFX_DSP24',0)+resources.get('EFX_DSP12',0)}/160 |
| XLR | {xlr}/60,800 |
| LUT4 / FF | {resources['EFX_LUT4']} / {resources['EFX_FF']} |
| DDR 桥独立随机读写与并发检查 | PASS；10,000 次随机命令及定向写后读、屏障与错误检查 |
| 系统最终风格像素核对 | {regressions['system']['pixels']} 像素一致 |
| 视频 / UI / CNN 跨时钟检查 | 全部通过 |
| 相机/串口/控制固件 | 4 组主机测试通过 |

相同完整尺寸、时钟和访存条件下，由 {baseline['contended_simulation_min_fps']:.3f} FPS 提高到 {fps:.3f} FPS，提升 {gain:.2f}%。以下为第一帧按原始逐层日志划分的耗时：

| 阶段 | 原版 ms | 优化版 ms |
|---|---:|---:|
{comparison}

资源变化：XLR {baseline['resources']['XLR']} → {xlr}；RAM 253 → {resources['EFX_RAM10']}；DSP 138 → {resources.get('EFX_DSP48',0)+resources.get('EFX_DSP12',0)}。

小图还覆盖 60% 总线随机停顿、48 周期首拍延迟、非整数时钟比、3 连续帧和 4 类 AXI R/B 错误各 2 帧。
系统回归覆盖采集、原图释放、显示帧所有权、APB IRQ 及逐像素检查。所有本轮集成仿真使用 Questa 2025.3。
独立 FIFO 单测复用哈希一致的既有 Icarus 记录（代码生成退出异常限制原样保留）；本轮重新执行整机正常 STA 及视频/UI/CNN CDC。
没有 UVM、代码覆盖率或门级 SDF 验证。未重新执行真实 CPU/PLIC 启动长仿真；固件源码未改，本轮重新构建；四组主机测试复用当前源码哈希一致的通过证据。
这是仿真访存条件下的性能，实板 PRC FPS、右窗口效果及长期稳定性尚待用户观察。

保持原始模型、量化和计算图；首层权重仅做可逆槽位重排。优化包含双读缓存、双写缓冲、读写并行和提前读返回、连续写突发、首层 RGB tap 打包、8 通道量化、累加器初始化重叠及相邻上采样窗口复用。两个残差乘法用逻辑实现，其余使用 DSP。逐层参考模型独立于上述 RTL 变换。整机开启 seq_opt=1、seq-opt-sync-only=1，仅对同步逻辑做等价优化；保持 retiming=0。
原包 189 项哈希、各层配置、MAC/均值/统计模块和量化公式由门禁检查；打包权重逐字校验。当前轮源码快照位于 work/u8_optimization/baseline/，8.725 FPS 的旧 U8 位流保留在 outputs/student_u8_v2/。
"""
    (R/'doc/u8_optimization_results.md').write_text(report,encoding='utf-8')
    records.add('doc/u8_optimization_results.md')
    out=R/'outputs/student_u8_optimized';out.mkdir(parents=True,exist_ok=True)
    for name in sorted(records):
        dst=out/'evidence'/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/name,dst)
    for ext in ['bit','hex']:shutil.copy2(R/f'work/efinity_out/ArtFlow.{ext}',out/f'ArtFlow_student_u8_optimized.{ext}')
    (out/'verification_results.md').write_text(report,encoding='utf-8')
    note=f"""# Student U8 整机吞吐优化上板预览

下载 ArtFlow_student_u8_optimized.bit，观察右侧 U8 模型风格效果；左侧原图和原有按键保持原流程。
OSD 仍为 V09，CAP FPS 为采集帧率，PRC FPS 为处理完成帧率。
CNN 为 142.857 MHz；APB cycles 仍按 100 MHz 计数，除以 100,000 得毫秒。
仿真最低处理速度 {fps:.3f} FPS，实际板上帧率待测；详见 verification_results.md。
串口为 115200 8N1，可间隔一段时间执行两次 status，观察 done/IRQ 增长及 error。
同一候选已同步到 outflow/ArtFlow.bit。旧 U8 8.725 FPS 位流保留在 outputs/student_u8_v2/，本轮源码修改前快照保存在 work/u8_optimization/baseline/。
未提交 Git，未自动下载板卡。
"""
    (out/'README.md').write_text(note,encoding='utf-8')
    manifest=dict(version='student-u8-system-throughput-optimized',status='READY_FOR_BOARD_TEST',board_verified=False,git_committed=False,
                  base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),
                  cnn_hz=2e9/14,axi_hz=1e8,output_slot=1,source_sha256=sources,
                  baseline_fps=baseline['contended_simulation_min_fps'],performance_gain_percent=gain,
                  frame_cycles_100mhz=cycles,contended_simulation_min_fps=fps,minimum_slack_ns=impl['minimum_slack_ns'],resources=resources,
                  regression={**{name:obj['status'] for name,obj in regressions.items()},'bridge_unit':bridge['status']},
                  reused_fifo_evidence=dict(status=fifo['status'],source_matched=True),
                  pending=['Board image effect, PRC FPS and long-run stability','Production CPU/PLIC board confirmation'])
    manifest['files']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file() and p.name!='manifest.json'}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for ext in ['bit','hex']:
        shutil.copy2(out/f'ArtFlow_student_u8_optimized.{ext}',R/f'outflow/ArtFlow.{ext}')
        assert sha(out/f'ArtFlow_student_u8_optimized.{ext}')==sha(R/f'outflow/ArtFlow.{ext}')
    print(note)
if __name__=='__main__':main()

