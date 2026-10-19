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
             'tools/run_u8_system.py','tools/run_u8_regression.py','tools/package_u8.py',
             'tools/run_efinity.ps1','doc/u8_integration.md','work/u8_integration/regression.json',
             'outputs/firmware/build_manifest.json','outputs/firmware/host_tests.json',
             'outputs/firmware/host_test_source_sha256.json'}
    gates={}
    for path in ['work/implementation_summary.json','work/video_cdc_summary.json','work/ui_cdc_summary.json','work/cnn_cdc_summary.json']:
        obj=read(path);assert obj['status']=='PASS',path;matches(obj['sha256']);gates[path]=obj;records.add(path)
        records.update(n for n in obj['sha256'] if Path(n).suffix in ['.rpt','.log','.sdc','.json','.tcl','.py','.ps1'])
    timing=(R/'work/efinity_out/ArtFlow.timing.rpt').read_text()
    assert re.search(r'^cnn_clk\s+cnn_clk\s+7\.000\s+\d+\.\d+',timing,re.M),'CNN not timed at 7 ns'
    assert 'create_clock -period 7.000 -name cnn_clk' in (R/'work/efinity_out/ArtFlow.pt.sdc').read_text()
    cases=['smoke_32x28_c3.5_v1','stress_48x36_c3.7_v1',*[f'fault{i}_32x28_c3.5_v0' for i in range(1,5)],'system','full_960x540_c3.5_v1']
    regressions={}
    for name in cases:
        rel='work/u8_integration/'+name
        obj=read(rel+'/summary.json');assert obj['status']=='PASS',name
        matches(obj['source_sha256']);matches(obj['evidence_sha256'],R/rel)
        records.add(rel+'/summary.json');records.update(rel+'/'+n for n in obj['evidence_sha256'])
        regressions[name]=obj
    # Reuse unchanged FIFO unit evidence, explicitly marked as previous evidence.
    previous='work/v09_perf/cdc'
    fifo=read(previous+'/summary.json')
    assert fifo['status'] in ['PASS','PASS_WITH_TOOL_LIMITATIONS']
    matches(fifo['source_sha256']);matches(fifo['evidence_sha256'],R/previous)
    records.add(previous+'/summary.json');records.update(previous+'/'+n for n in fifo['evidence_sha256'])
    full=regressions['full_960x540_c3.5_v1']
    assert full['args']['frames']==2 and full['feature_words']==782400
    cycles=full['frame_cycles_100mhz'];assert len(cycles)==2 and min(cycles)>0
    assert regressions['system']['pixels']>=6*896
    logs=(W/'full_960x540_c3.5_v1/simulation.log').read_text()
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
    report=f"""# Student U8 RTL Optimized V2 整机预览验证结果

状态：READY_FOR_BOARD_TEST。当前原工程已替换为新 U8 模型；本次没有提交 Git，也没有下载板卡。

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
| 系统最终风格像素核对 | {regressions['system']['pixels']} 像素一致 |
| 视频 / UI / CNN 跨时钟检查 | 全部通过 |
| 相机/串口/控制固件 | 4 组主机测试通过 |

小图还覆盖 60% 总线随机停顿、48 周期首拍延迟、非整数时钟比、3 连续帧和 4 类 AXI R/B 错误各 2 帧。
系统回归覆盖采集、原图释放、显示帧所有权、APB IRQ 及逐像素检查。所有本轮集成仿真使用 Questa 2025.3。
独立 FIFO 单测复用哈希一致的既有 Icarus 记录（代码生成退出异常限制原样保留）；本轮重新执行整机正常 STA 及视频/UI/CNN CDC。
没有 UVM、代码覆盖率或门级 SDF 验证。未重新执行真实 CPU/PLIC 启动长仿真；固件源码未改，本轮重新构建并跑主机测试。
这是仿真访存条件下的性能，实板 PRC FPS、右窗口效果及长期稳定性尚待用户观察。

部署核心相对集成包有 ROM 路径替换、line_waddr 声明顺序调整和三组小系数 ROM 的逻辑实现属性；没有改变权重、表达式或计算图。整机开启 seq_opt=1、seq-opt-sync-only=1，仅对同步逻辑做等价优化；保持 retiming=0。
原包 189 项哈希及部署变换由门禁检查。之前未提交的性能修改保留，本轮修改前备份位于 work/u8_integration/before/。
"""
    (R/'doc/u8_verification_results.md').write_text(report,encoding='utf-8')
    records.add('doc/u8_verification_results.md')
    out=R/'outputs/student_u8_v2';out.mkdir(parents=True,exist_ok=True)
    for name in sorted(records):
        dst=out/'evidence'/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(R/name,dst)
    for ext in ['bit','hex']:shutil.copy2(R/f'work/efinity_out/ArtFlow.{ext}',out/f'ArtFlow_student_u8_v2.{ext}')
    (out/'verification_results.md').write_text(report,encoding='utf-8')
    note=f"""# Student U8 V2 上板预览

下载 ArtFlow_student_u8_v2.bit，观察右侧 U8 模型风格效果；左侧原图和原有按键保持原流程。
OSD 仍为 V09，CAP FPS 为采集帧率，PRC FPS 为处理完成帧率。
CNN 为 142.857 MHz；APB cycles 仍按 100 MHz 计数，除以 100,000 得毫秒。
仿真最低处理速度 {fps:.3f} FPS，实际板上帧率待测；详见 verification_results.md。
串口为 115200 8N1，可间隔一段时间执行两次 status，观察 done/IRQ 增长及 error。
同一候选已同步到 outflow/ArtFlow.bit。旧 S8 预览保留在 outputs/v09_222mhz/，替换前的 outflow 位流也保存在 work/u8_integration/before/。
未提交 Git，未自动下载板卡。
"""
    (out/'README.md').write_text(note,encoding='utf-8')
    manifest=dict(version='student-u8-optimized-v2-preview',status='READY_FOR_BOARD_TEST',board_verified=False,git_committed=False,
                  base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),
                  cnn_hz=2e9/14,axi_hz=1e8,output_slot=1,source_sha256=sources,
                  frame_cycles_100mhz=cycles,contended_simulation_min_fps=fps,minimum_slack_ns=impl['minimum_slack_ns'],resources=resources,
                  regression={name:obj['status'] for name,obj in regressions.items()},
                  reused_fifo_evidence=dict(status=fifo['status'],source_matched=True),
                  pending=['Board image effect, PRC FPS and long-run stability','Production CPU/PLIC board confirmation'])
    manifest['files']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file() and p.name!='manifest.json'}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for ext in ['bit','hex']:
        shutil.copy2(out/f'ArtFlow_student_u8_v2.{ext}',R/f'outflow/ArtFlow.{ext}')
        assert sha(out/f'ArtFlow_student_u8_v2.{ext}')==sha(R/f'outflow/ArtFlow.{ext}')
    print(note)
if __name__=='__main__':main()

