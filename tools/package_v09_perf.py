"""Publish a source-matched 222.222 MHz candidate after timing, CDC and >15 fps gates."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
from check_project_v05 import implementation_sources,check_firmware
R=Path(__file__).resolve().parents[1]
BASE='5c2218cf6bc2fe10b4b30b76a74ab303d2e7b712'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads((R/p).read_text(encoding='utf-8'))
def matches(items,base=R):
    for n,d in items.items():assert sha(base/n)==d,'Stale evidence: '+n
def main():
    subprocess.check_call([sys.executable,'-B',str(R/'tools/check_project_v09.py'),'--check-snapshot'],cwd=R)
    check_firmware();sources=implementation_sources()
    assert sources==read('work/implementation_source_sha256.json')
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==BASE,'Unexpected commit'
    assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R,text=True).strip(),'Unexpected staged changes'
    records=set(['work/implementation_source_sha256.json','work/efinity_compile.log',
        'work/efinity_out/ArtFlow.map.rpt','work/efinity_out/ArtFlow.place.rpt',
        'work/efinity_out/ArtFlow.timing.rpt','work/efinity_out/ArtFlow.pt.sdc',
        'doc/v09_performance_notes.md','doc/v09_performance_verification_plan.md',
        'tools/package_v09_perf.py','tools/run_efinity.ps1','tools/check_project_v09.py',
        'outputs/firmware/build_manifest.json','outputs/firmware/host_tests.json',
        'outputs/firmware/host_test_source_sha256.json'])
    gates={}
    for path in ['work/implementation_summary.json','work/video_cdc_summary.json','work/ui_cdc_summary.json','work/cnn_cdc_summary.json']:
        obj=read(path);assert obj['status']=='PASS',path;matches(obj['sha256'])
        records.add(path);gates[path]=obj
        records.update(n for n in obj['sha256'] if Path(n).suffix in ['.rpt','.log','.sdc','.json','.tcl','.py','.ps1'])
    timing=(R/'work/efinity_out/ArtFlow.timing.rpt').read_text()
    assert re.search(r'^cnn_clk\s+cnn_clk\s+4\.500\s+\d+\.\d+',timing,re.M),'222.222 MHz CNN not timed'
    assert 'create_clock -period 4.500 -name cnn_clk' in (R/'work/efinity_out/ArtFlow.pt.sdc').read_text(),'PLL/SDC clock mismatch'
    cases=[f'final/sim_32x28_f{i}_s25_r12_c2.25_v0' for i in range(1,5)]
    cases+=['final/sim_64x44_f0_s25_r12_c2.25_v1','final/sim_64x44_f0_s60_r48_c2.7_v0',
            'questa_960x540_c2.25_v1','system','cdc']
    summaries={}
    for path in [*(f'work/v09_perf/{c}' for c in cases),'work/v09/color','work/v09/control']:
        obj=read(path+'/summary.json');assert obj['status'] in ['PASS','PASS_WITH_TOOL_LIMITATIONS'],path
        matches(obj['source_sha256']);matches(obj['evidence_sha256'],R/path)
        summaries[path]=obj;records.add(path+'/summary.json')
        records.update(path+'/'+n for n in obj['evidence_sha256'])
    perf=summaries['work/v09_perf/questa_960x540_c2.25_v1']
    assert perf['args']['frames']>=2 and perf['feature_words']==572280
    cycles=perf['frame_cycles_100mhz'];assert len(cycles)==perf['args']['frames'] and min(cycles)>0
    fps=100000000/max(cycles);assert fps>15,'Full-size contended simulation does not exceed 15 fps'
    log=(R/'work/v09_perf/questa_960x540_c2.25_v1/simulation.log').read_text()
    traffic=re.search(r'TRAFFIC read_beats=(\d+) write_beats=(\d+)',log);assert traffic
    read_mbps=int(traffic[1])*16*100/sum(cycles);write_mbps=int(traffic[2])*16*100/sum(cycles)
    assert read_mbps>=250 and write_mbps>=62.5,'Competing video traffic was below its budget'
    assert summaries['work/v09_perf/system']['pixels']>=6*896
    system_log=(R/'work/v09_perf/system/simulation.log').read_text()
    system=re.search(r'tb_v09_system PASS jobs=(\d+) done=(\d+) irq=(\d+) skip=(\d+) pixels=(\d+) underflow=(\d+)',system_log)
    assert system and system[1]==system[2]==system[3]
    soc=read('work/v09/soc_questa/summary.json')
    matches(soc['source_sha256'])
    if soc['status']=='PASS':
        soc_status='PASS'
        soc_note='生产 CPU/PLIC 的成功和 NACK 回归均通过；完成事件来自定时外设，真实 CNN 数据面由其他回归覆盖。'
        for name in ['success','nack']:
            path=f'work/v09/soc_questa/{name}.log';txt=(R/path).read_text()
            assert 'tb_v09_soc_boot PASS' in txt and not re.search(r'\*\* (Error|Fatal|Warning):',txt)
            records.add(path)
    else:
        attempt=read('work/v09/soc_questa/attempt.json')
        assert attempt['status']=='NOT_COMPLETED'
        assert attempt['summary_sha256']==sha(R/'work/v09/soc_questa/summary.json')
        matches(attempt['evidence_sha256'],R/'work/v09/soc_questa')
        soc_status='NOT_COMPLETED'
        soc_note='生产 CPU 补测编译通过并输出固件启动信息，约九分钟后在摄像头初始化阶段主动停止，以释放单实例许可给完整尺寸 CNN 回归；状态为 NOT_COMPLETED，未宣称 CPU/PLIC 联调通过。保留原始进程中止日志，后续可独立复跑；固件本轮未改。'
        records.update(['work/v09/soc_questa/attempt.json','work/v09/soc_questa/success.log'])
    records.update(['work/v09/soc_questa/summary.json','work/v09/soc_questa/compile.log','tools/run_v09_soc.py','sim/tb_v09_soc_boot.sv'])
    assert all(x['passed'] for x in read('outputs/firmware/host_tests.json'))
    matches(read('outputs/firmware/host_test_source_sha256.json'))
    matches(read('doc/v09_baseline.json')['network_inputs'])
    resources={k:int(v) for k,v in re.findall(r'^(EFX_\w+)\s*:\s*(\d+)\s*$',(R/'work/efinity_out/ArtFlow.map.rpt').read_text(),re.M)}
    assert resources['EFX_RAM10']<=256 and resources['EFX_DSP48']+resources['EFX_DSP24']<=160
    impl=gates['work/implementation_summary.json'];cdc=gates['work/cnn_cdc_summary.json']
    report=f'''# v09 222.222 MHz 性能候选验证结果

此候选在带后台视频流量的完整尺寸 RTL 仿真中，每帧处理速度均大于 15 FPS；尚未上板测量，不能将仿真值称为板上稳定帧率。

| 项目 | 结果 |
|---|---|
| CNN / AXI / CPU | 222.222 / 100 / 100 MHz；摄像头、DDR PHY、HDMI 时钟保持基线 |
| 网络与画质合同 | 相同 22 层 W8/A4/S8 权重；480×270 输入，960×540 输出；逐比特保持 |
| 连续完整帧 | {len(cycles)} 帧，每帧 518,400 最终像素、572,280 中间特征及地址比对通过 |
| 100 MHz 墙钟周期 | {', '.join(format(n,',') for n in cycles)} |
| 每帧耗时 | {', '.join(f'{n/100000:.5f}' for n in cycles)} ms |
| 最低条件处理帧率 | {fps:.4f} FPS |
| 同时后台视频流量 | 读 {read_mbps:.2f} MB/s、写 {write_mbps:.2f} MB/s；视频 burst 优先 |
| DDR 模型等待 | 首拍 12 个 AXI 周期，各通道 25% 随机等待 |
| 最差 setup / hold | {impl['minimum_slack_ns']['Setup (Max)']:+.3f} / {impl['minimum_slack_ns']['Hold (Min)']:+.3f} ns |
| RAM10 / DSP | {resources['EFX_RAM10']}/256；{resources['EFX_DSP48']+resources['EFX_DSP24']}/160 |
| LUT4 / FF | {resources['EFX_LUT4']:,} / {resources['EFX_FF']:,} |
| 新增 CDC | {cdc['gray_endpoints']} 个 Gray 接收位；{cdc['synchronizer_setup_hold_paths']} 条同步器 setup/hold 路径全部通过 |
| 新增 CDC 最长数据路径 | {max(v['maximum_data_delay_ns'] for v in cdc['crossing_groups']):.3f} ns；Gray 预算 4.5 ns，稳定 payload 预算 8 ns |

小图另外覆盖非整数时钟比、60% 随机等待、48 周期首拍延迟和 3 连续帧；4 类 AXI R/B 错误各 2 帧。系统测试采集 20 帧、完成 {system[2]} 帧及 {system[3]} 次 IRQ，{summaries['work/v09_perf/system']['pixels']:,} 个风格像素与 Python 一致，{int(system[5]):,} 个显示像素与帧快照一致，仅首次无有效帧时出现 {system[6]} 次欠载。FIFO 双向随机测试累计检查 14,524 / 17,463 字，并覆盖满队列背压和运行中公共复位。

独立 100 MHz 基线是 9.7936 FPS（无上述后台流量）；测试场景不同，不能把两者当作同条件实板加速比。

工具为 Efinity 2026.1.132 / Ti60F225 I3、Questa 2025.3（完整尺寸连续帧）与 Icarus 13.0（其他四态回归）。Icarus 仍存在代码生成后异常退出，所有采用的 VVP 均为新生成且运行退出码 0、scoreboard 完成，标记 PASS_WITH_TOOL_LIMITATIONS。没有 UVM 或代码/功能覆盖率数据库。Questa 的沙箱 DLL 启动问题已通过正常本机运行解决。{soc_note}

待用户上板：真实 DDR 时延与刷新、相机输入速率、固件调度开销、PRC FPS、显示稳定性及温升下长期运行。ROM 权重、动态 APB 加载等原 v09 验收边界不因提频改变。Git 基线 {BASE[:7]}，本轮未提交。
'''
    (R/'doc/v09_performance_results.md').write_text(report,encoding='utf-8')
    records.add('doc/v09_performance_results.md')
    out=R/'outputs/v09_222mhz';out.mkdir(parents=True,exist_ok=True)
    for n in sorted(records):
        dst=out/'evidence'/n;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/n,dst)
    for ext in ['bit','hex']:shutil.copyfile(R/f'work/efinity_out/ArtFlow.{ext}',out/f'ArtFlow_v09_222MHz.{ext}')
    (out/'verification_results.md').write_text(report,encoding='utf-8')
    note=f'''# v09 222.222 MHz 上板候选

下载 `ArtFlow_v09_222MHz.bit`。网络、权重、分辨率、按键和白平衡保持原版本；CNN 独立运行于 222.222 MHz，AXI、CPU 仍为 100 MHz。

完整尺寸连续 {len(cycles)} 帧，在约 {read_mbps+write_mbps:.0f} MB/s 后台视频流量下逐比特通过；最低仿真处理速度 **{fps:.2f} FPS**。这是仿真结果，板上稳定大于 15 FPS 待确认。实际资源、时序、测试边界见 `verification_results.md`。

1. 下载后等待原有开机流程，OSD 仍显示 V09、CAP FPS / PRC FPS。
2. 观察右侧风格、RGB、错行、闪烁、撕裂；PRC 是完成的风格帧数。
3. 串口 115200 8N1，间隔 60 秒执行两次 `status`，以 done 增量 / 实际间隔测量长期帧率，并确认 error 为 0、IRQ 持续增长。
4. `cycles` 仍是 100 MHz 墙钟周期，除以 100,000 得毫秒；不要除以 222.222 MHz。
5. 连续运行至少 30 分钟检查稳定性。若 CAP 自身不大于 15 FPS，处理输出也不可能稳定超过输入速度。

原工程 `outflow/ArtFlow.bit` 与本候选相同；100 MHz 回退镜像保留在原工程 `outputs/v09/ArtFlow_v09.bit`（对应提交 {BASE[:7]}）。本轮未提交 Git、未自动下载板卡。
'''
    (out/'README.md').write_text(note,encoding='utf-8')
    manifest=dict(version='v09-s8-222mhz-preview',status='READY_FOR_BOARD_TEST',board_verified=False,
                  git_committed=False,base_commit=BASE,cnn_hz=2000000000/9,axi_hz=100000000,
                  frame_cycles_100mhz=cycles,contended_simulation_min_fps=fps,
                  competing_read_MBps=read_mbps,competing_write_MBps=write_mbps,
                  minimum_slack_ns=impl['minimum_slack_ns'],resources=resources,
                  source_sha256=sources,regression={k:{n:v[n] for n in ['status','tool_limitations']} for k,v in summaries.items()},
                  production_cpu_regression=soc_status,
                  pending_acceptance=['Board PRC FPS >15 and long-run stability','Production CPU/PLIC board confirmation','Original v09 runtime weight-loading requirements'])
    manifest['files']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file() and p.name!='manifest.json'}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for ext in ['bit','hex']:
        shutil.copyfile(out/f'ArtFlow_v09_222MHz.{ext}',R/f'outflow/ArtFlow.{ext}')
        assert sha(out/f'ArtFlow_v09_222MHz.{ext}')==sha(R/f'outflow/ArtFlow.{ext}')
    print(note)
if __name__=='__main__':main()
