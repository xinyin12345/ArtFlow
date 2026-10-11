"""Package only after full arithmetic, source provenance and routed timing pass."""
from pathlib import Path
import json,re,hashlib,shutil,zipfile,argparse
R=Path(__file__).resolve().parent
p=argparse.ArgumentParser()
p.add_argument('--pnr',default='pnr_20261010_202809');p.add_argument('--map',default='map_20261010_202651')
args=p.parse_args();PNR=args.pnr;MAP=args.map
def read(p):return p.read_text(encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def observed(folder):
    q=R/'reports'/folder;x=json.loads(read(q/'result.json'))
    log=read(q/'simulation.log');assert x['returncode']==0 and 'FAIL' not in log
    matches=re.findall(r'PASS frame=(\d+) cycles=(\d+) reads=(\d+) writes=(\d+)',log)
    assert matches
    return x,[tuple(map(int,m)) for m in matches],log
pnr=json.loads(read(R/'reports'/PNR/'result.json'));assert pnr['returncode']==0
stage=Path(pnr['stage'])
assert (stage/'s8_shared_flat.v').read_bytes()==(R/'s8_shared_flat.v').read_bytes()
assert (stage/'clock.sdc').read_bytes()==(R/'clock.sdc').read_bytes()
for p in (R/'mem').glob('*.mem'):assert p.read_bytes()==(stage/'mem'/p.name).read_bytes()
place=read(R/'reports'/PNR/'outflow/s8_shared.place.rpt')
timing=read(R/'reports'/PNR/'outflow/s8_shared.timing.rpt')
resources={k:int(re.search(p,place).group(1)) for k,p in dict(xlr=r'XLRs: (\d+)',ram=r'Memory Blocks: (\d+)',dsp=r'DSP Blocks: (\d+)').items()}
assert resources['xlr']<=33000 and resources['ram']<=120 and resources['dsp']<=144
rows=re.findall(r'\n\s+clk\s+clk\s+([\d.]+)\s+([-\d.]+)\s+\(R-R\)',timing)
assert len(rows)==2
period,setup=float(rows[0][0]),float(rows[0][1]);hold=float(rows[1][1])
assert setup>=0 and hold>=0
frequency=1000./period
max_frequency=float(re.search(r'\n\s+clk\s+[\d.]+\s+([\d.]+)\s+\(R-R\)',timing).group(1))
sim,measurements,log=observed('sim_480x270_L3_S1_random')
assert sim['checked_integer'] and sim['args']['width']==480 and sim['args']['height']==270
for p in (R/'rtl').iterdir():
    if p.suffix in ['.v','.vh']:assert sha(p)==sim['rtl_sha256']['rtl\\'+p.name]
for p in (R/'mem').glob('*.mem'):
    assert p.read_bytes()==(Path(sim['stage'])/'mem'/p.name).read_bytes()
_,control,_=observed('sim_480x270_L3_S1_random_count')
assert measurements==control,'Arithmetic and controller timings differ'
_,slow,_=observed('sim_480x270_L10_S1_random_count')
_,cycles,reads,writes=measurements[0]
assert reads==622200 and writes==572280
gate=json.loads(read(R/'reports/gate_prefix/result.json'));assert gate['returncode']==0
assert (Path(gate['stage'])/'core.v').read_bytes()==(R/'reports'/PNR/'outflow/s8_shared.map.core.v').read_bytes()
param=json.loads(read(R/'parameter_readback_audit.json'));assert param['pass_all']
test,long_frames,_=observed('sim_32x22_L20_S1_random')
assert test['checked_integer'] and len(long_frames)==2
assert sim['rtl_sha256']['rtl\\s8_shared.v']==test['rtl_sha256']['rtl\\s8_shared.v']
video=dict(xlr=21557,ram=119,dsp=10);total=dict(xlr=60800,ram=256,dsp=160)
combined={k:video[k]+resources[k] for k in total}
audit=dict(resources=resources,clock_period_ns=period,clock_mhz=frequency,
    analyzed_max_clock_mhz=max_frequency,setup_slack_ns=setup,hold_slack_ns=hold,
    rtl_sha256=sha(R/'s8_shared_flat.v'),model_sha256=param['model_sha256'],
    full_arithmetic_verification=dict(status='passed',cycles=cycles,reads=reads,writes=writes,all_feature_writes_compared=True,all_write_addresses_compared=True),
    frame_time_ms=cycles*period/1e6,conditional_fps=frequency*1e6/cycles,
    slow_ddr_cycles=slow[0][1],slow_ddr_conditional_fps=frequency*1e6/slow[0][1],
    traffic_bytes=(reads+writes)*8,video_resources_from_user=video,projected_combined_resources=combined,
    remaining_after_projection={k:total[k]-combined[k] for k in total},
    scope='Standalone CNN core. FPS is cycle simulation times routed clock, not board video measurement. No DDR burst bridge, physical pin/PLL/CDC integration or SDF simulation.')
(R/'final_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
baseline=16629866
text='''# 480×270 CNN v2 实测报告

已实际使用本机 Efinity 2026.1.132，对 Ti60F225、I3 完成独立 CNN 核综合及布局布线；完整 480×270 真实算术 RTL 已通过冻结整数模型逐笔核对。

## 新旧对比

| 项目 | 原版 | v2 |
|---|---:|---:|
| XLR | 5,553 | %(xlr)d |
| RAM 块 | 73 | %(ram)d |
| DSP | 122 | %(dsp)d |
| 已通过的布局布线时钟 | 125 MHz | %(frequency).3f MHz（周期 %(period).3f ns） |
| 每帧周期，读延迟 3、ready 随机等待约 1/8 | 16,629,866 | %(cycles)d |
| 核心处理时间 | 133.039 ms | %(ms).3f ms |
| 条件帧率 | 7.517 fps | %(fps).3f fps |

同一访存测试条件下，每帧周期减少 %(reduction).2f%%。时钟与周期协同改善后的条件帧率约为原来的 %(speedup).2f 倍。若 v2 仍以 125 MHz 工作，条件帧率只有 %(fps125).3f fps，因此本次约 150 MHz 的真实时序通过是达到目标的一部分。

## 时序结果

- Setup 最差余量：%(setup)+.3f ns。
- Hold 最差余量：%(hold)+.3f ns。
- 工具分析最高频率：%(max_frequency).3f MHz；未据此把工作频率设为分析极限。
- 最终最大路径已从旧版的行号控制判断转移到窗口 bank 选择至 MAC 的 DW 数据选择路径。
- 没有添加假路径或多周期例外来回避关键路径。SDC 只定义内部时钟；外部端口尚无整板接口时序约束。
- 原始报告：`reports/%(pnr)s/outflow/s8_shared.timing.rpt`、`s8_shared.place.rpt`。

## 对照视频系统资源

| 资源 | 视频已用（截图） | CNN 布局布线实测 | 直接相加 | 全片总量 | 相加后剩余 |
|---|---:|---:|---:|---:|---:|
| XLR | 21,557 | %(xlr)d | %(combined_xlr)d | 60,800 | %(remain_xlr)d |
| RAM | 119 | %(ram)d | %(combined_ram)d | 256 | %(remain_ram)d |
| DSP | 10 | %(dsp)d | %(combined_dsp)d | 160 | %(remain_dsp)d |

相加是集成前预算，尚未包含后续 DDR 桥接、跨时钟 FIFO 等新增资源，不是整系统综合报告。当前不需要为了用满资源而继续增加 MAC。

## 实际修改

窗口、MAC 和量化写回三个工作器并发；A/B 窗口轮换；累加值、skip、参数和地址独立快照；背压时锁存命令；行反射、槽选择、命中判断及列地址分拍；Up2+DW 仅读取四个不同源位置，并映射回原来九个 tap。网络仍逐层执行，窗口缓冲不存整帧。

权重、偏置、尺度、反射边界、Up2、残差单次舍入及 RGB nearest-even 都没有改动。外部 480×270，内部 480×272；最后两行仅用于原有边界规则，RGB 不写出这两行。

## 验证与限制

1. 完整随机 480×270：比较全部 572,280 次 64 位特征写回及地址，涵盖 22 层，读 622,200 次；通过。真实算术周期与快速控制仿真完全一致。
2. 32×22 连续两帧、读延迟 20 周期及随机背压：通过，检查所有特征字、地址和命令稳定。
3. 初期 16×14、32×22 连续两帧用于检查调度；对应日志保留，最终源码一致性由完整尺寸与长延迟测试确认。
4. 参数布局核对：44,220 个权重、555 个偏置、555 个主尺度乘数、4 个 skip 乘数全部匹配。S20 累加绝对值界 365,775，安全。
5. 实际综合网表、原厂单元功能仿真：首编码层第一行 240 个输出通过，7,714 周期。仅为局部综合网表功能检查，不是全网门级或 SDF 时序仿真。

每帧特征流量 %(traffic)d 字节，约 9.56 MB。本次优化减少了计算和调度等待，未减少对外特征流量，也未实现板级 DDR 突发桥。

**%(fps).3f fps 是条件估算，不是板上视频实测。** 仿真中的 3 周期返回是 CNN 逻辑接口条件，不能直接解释为物理 DDR 延迟。读延迟改为 10 周期后，控制仿真为 %(slow_cycles)d 周期，条件帧率 %(slow_fps).3f fps。接入视频工程时必须验证缓存/突发和仲裁；还未计入采集、格式重排、输出搬运和显示同步。

建议以约 150 MHz 集成，重新检查整系统时序及 CDC；验证真实 DDR 条件下每帧总耗时不超过 66.67 ms、持续完成帧率不低于 15。摄像头/显示时钟分别保持接口要求，通过标准跨时钟桥连接。没有固定视频输入测试，不声称已经完成时序画质验证。

复现命令、问题处理和 Efinity 手动操作见 `优化与操作记录.md`。该包为独立核 RTL 与验证交付，尚非可直接上板的视频整机比特流。
'''%dict(resources,frequency=frequency,period=period,cycles=cycles,ms=audit['frame_time_ms'],fps=audit['conditional_fps'],
    reduction=100*(1-cycles/float(baseline)),speedup=audit['conditional_fps']/(125e6/baseline),fps125=125e6/cycles,
    setup=setup,hold=hold,pnr=PNR,max_frequency=max_frequency,combined_xlr=combined['xlr'],combined_ram=combined['ram'],combined_dsp=combined['dsp'],
    remain_xlr=total['xlr']-combined['xlr'],remain_ram=total['ram']-combined['ram'],remain_dsp=total['dsp']-combined['dsp'],
    traffic=audit['traffic_bytes'],slow_cycles=slow[0][1],slow_fps=audit['slow_ddr_conditional_fps'])
(R/'实测报告.md').write_text(text,encoding='utf-8')
conf=json.loads(read(R/'architecture.json'))['layers']
old=json.loads(read(R/'baseline_performance.json'))['layers']
new_rows=re.findall(r'LAYER index_next=\d+ cycles=(\d+) writes=(\d+) reads=(\d+)',log)
assert len(new_rows)==22
prev=0;layer_perf=[]
for c,b,m in zip(conf,old,new_rows):
    end=int(m[0]);layer_perf.append(dict(name=c['name'],baseline_cycles=b['cycles'],v2_cycles=end-prev));prev=end
(R/'performance_audit.json').write_text(json.dumps(dict(layers=layer_perf,total_cycles=cycles),indent=2),encoding='utf-8')
O=R.parent/'output/s8_480x270_v2_20261010';O.mkdir(parents=True,exist_ok=True)
D=O/'S8_480x270_Pipeline_v2';assert not D.exists(),'Preserve prior delivery'
D.mkdir()
for folder in ['rtl','mem']:
    shutil.copytree(str(R/folder),str(D/folder),ignore=shutil.ignore_patterns('*.bak'))
for p in R.iterdir():
    if p.is_file() and p.suffix in ['.py','.v','.xml','.sdc','.json','.md']:shutil.copy2(str(p),str(D/p.name))
ref=D/'reference';(ref/'exports').mkdir(parents=True)
refsrc=R/'reference' if (R/'reference').exists() else R.parent/'style_s8_integer'
for name in ['integer_model.py','integer_ops.py']:shutil.copy2(str(refsrc/name),str(ref/name))
for name in ['graph.json','model_int.npz','parameter_manifest.json']:shutil.copy2(str(refsrc/'exports'/name),str(ref/'exports'/name))
for name in [PNR,MAP]:shutil.copytree(str(R/'reports'/name),str(D/'reports'/name))
for q in (R/'reports').glob('sim_*'):
    if not (q/'result.json').exists():continue
    dest=D/'reports'/q.name;dest.mkdir()
    for name in ['result.json','simulation.log','tb.v']:shutil.copy2(str(q/name),str(dest/name))
shutil.copytree(str(R/'reports/gate_prefix'),str(D/'reports/gate_prefix'))
(D/'SHA256SUMS.json').write_text(json.dumps({str(p.relative_to(D)):sha(p) for p in D.rglob('*') if p.is_file()},indent=2,ensure_ascii=False),encoding='utf-8')
archive=O/'S8_480x270_Pipeline_v2_20261010.zip'
with zipfile.ZipFile(str(archive),'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in D.rglob('*'):
        if p.is_file():z.write(str(p),str(p.relative_to(O)))
with zipfile.ZipFile(str(archive)) as z:assert z.testzip() is None
(O/'delivery.json').write_text(json.dumps(dict(archive=str(archive),bytes=archive.stat().st_size,sha256=sha(archive),audit=audit),indent=2),encoding='utf-8')
print(json.dumps(dict(archive=str(archive),bytes=archive.stat().st_size,audit=audit),indent=2))
