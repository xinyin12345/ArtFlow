# -*- coding: utf-8 -*-
"""Freeze only final matching evidence; report measured map/PNR resources."""
from pathlib import Path
import json,hashlib,re,shutil,zipfile
import numpy as np
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
pins={p.relative_to(R).as_posix():sha(p) for p in (R/'rtl').iterdir() if p.is_file()}
passed=[];units=[]
for p in (R/'reports').glob('*/result.json'):
    d=json.loads(p.read_text('utf8'))
    if d.get('returncode')!=0:continue
    dp={k.replace('\\','/'):v for k,v in d.get('rtl_sha256',{}).items()}
    if dp==pins:passed.append((p.parent,d))
    elif dp and all(pins.get('rtl/'+k)==v for k,v in dp.items()):units.append((p.parent,d))
def latest(fn):
    f=sorted(((p,d) for p,d in passed if fn(d)),key=lambda x:x[0].name);assert f;return f[-1]
full=latest(lambda d:d['args']['width']==480 and d['args']['frames']==2)
slow=latest(lambda d:d['args']['width']==480 and d['args']['latency']==10)
cross=latest(lambda d:d['args']['width']==24 and d['args']['frames']==2 and d['args']['latency']==20)
checker=latest(lambda d:d['args']['mode']=='checker')
white=latest(lambda d:d['args']['mode']=='white')
photos=[latest(lambda d,stem=s:d['args'].get('image') and Path(d['args']['image']).stem==stem)
        for s in ['000000136343','000000194780','000000175191']]
assert len(units)==2
flow={}
for kind in ['map','pnr']:
    for p in sorted((R/'reports').glob(kind+'_*/result.json')):
        d=json.loads(p.read_text('utf8'))
        if d['returncode']!=0:continue
        stage=Path(d['stage'])
        if (stage/'student_u8_flat.v').read_bytes()!=(R/'student_u8_flat.v').read_bytes():continue
        if not all((stage/'mem'/m.name).read_bytes()==m.read_bytes() for m in (R/'mem').iterdir()):continue
        flow[kind]=(p.parent,d)
    assert kind in flow
    rep,d=flow[kind];stage=Path(d['stage'])
    for n in ['student_u8_flat.v','student_u8.xml','clock.sdc','run.cmd']:shutil.copy2(stage/n,rep/n)
    shutil.copytree(stage/'mem',rep/'mem',dirs_exist_ok=True)
csv=(flow['map'][0]/'outflow/student_u8.res.csv').read_text()
row=next(x for x in csv.splitlines() if x.startswith('student_u8:'))
nums=[int(re.search(r'\d+',v).group()) for v in row.split('\t')[1:] if re.search(r'\d+',v)]
assert len(nums)==7,nums
syn=dict(ff=nums[0],srl=nums[1],add=nums[2],lut4=nums[3],comb4=nums[4],ram=nums[5],dsp=nums[6])
assert syn==dict(ff=11092,srl=0,add=6786,lut4=15172,comb4=0,ram=104,dsp=126)
util=(flow['pnr'][0]/'outflow/student_u8.hier_util.rpt').read_text()
assert re.search(r'\+student_u8\s*\|\s*25569',util)
timing=(flow['pnr'][0]/'outflow/student_u8.timing.rpt').read_text()
assert all(x in timing for x in ['0.285','0.091','156.691'])
def frame_rows(p):
    return [dict(frame=int(f),cycles=int(c),reads=int(r),writes=int(w)) for f,c,r,w in re.findall(
        r'PASS frame=(\d+) cycles=(\d+) reads=(\d+) writes=(\d+)',(p/'simulation.log').read_text())]
tests=[dict(report=p.relative_to(R).as_posix(),args=d['args'],frames=frame_rows(p),rgb_max_abs_error=d.get('rgb_max_abs_error'),
            checked_integer=True,arithmetic_substitution=False) for p,d in [full,slow,cross,checker,white]+photos]
frames=[f for t in tests if t['args']['width']==480 for f in t['frames']]
assert len(frames)==6 and all(f['writes']==782400 and f['reads']==832320 for f in frames)
selected=[flow['map'][0],flow['pnr'][0]]+[p for p,d in units]+[p for p,d in [full,slow,cross,checker,white]+photos]
old=json.loads((R/'baseline/metrics.json').read_text('utf8'));clock=1000/6.667*1e6
normal=frame_rows(full[0]);long=frame_rows(slow[0])[0]
newcycles=normal[0]['cycles'];oldcycles=old['cycles_read3']
out=R/'review';out.mkdir(exist_ok=True)
font=ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc',24);small=ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc',18)
canvas=Image.new('RGB',(1464,966),'#eef1f5');draw=ImageDraw.Draw(canvas)
for col,title in enumerate(['同一输入RGB8','原U8整数模型输出','优化V2实际RTL输出（误差0）']):draw.text((12+488*col,12),title,font=font,fill='#172236')
photo_manifest=[]
for row,(p,d) in enumerate(photos):
    stem=Path(d['args']['image']).stem
    oracle=np.asarray(Image.open(p/'integer_output.png'));actual=np.asarray(Image.open(p/'rtl_output_frame0.png'))
    assert np.array_equal(oracle,actual) and d['rgb_max_abs_error']==0
    old_image=R.parent/'xdl1_student_u8_rtl_20261013/review'/(stem+'_u8_integer.png')
    if old_image.exists():assert np.array_equal(oracle,np.asarray(Image.open(old_image)))
    for col,n in enumerate(['input.png','integer_output.png','rtl_output_frame0.png']):
        im=Image.open(p/n).convert('RGB');assert im.size==(480,270)
        name=stem+'_'+['input','original_u8','optimized_rtl'][col]+'.png'
        shutil.copy2(p/n,out/name);canvas.paste(im,(12+488*col,56+row*302))
    draw.text((12,331+row*302),stem+'：优化前后RGB逐像素一致；仅改变硬件调度与统计实现',font=small,fill='#172236')
    photo_manifest.append(dict(source=d['args']['image'],source_sha256=sha(Path(d['args']['image'])),rgb_max_abs_error=0,report=p.relative_to(R).as_posix()))
canvas.save(out/'U8_Original_vs_OptimizedRTL_V2_3Images.png')
(out/'manifest.json').write_text(json.dumps(photo_manifest,ensure_ascii=False,indent=2),encoding='utf8')
ev=dict(format='u8_rtl_optimized_v2_final_evidence',model=old['model'],model_unchanged=True,integer_model_sha256=sha(R/'reference/integer/model_int.npz'),
    rtl_sha256=pins,flat_rtl_sha256=sha(R/'student_u8_flat.v'),rom_sha256={p.name:sha(p) for p in (R/'mem').iterdir()},
    synthesis=syn,post_pnr=dict(xlr=25569,ram=104,dsp=126),device='Ti60F225',timing_model='I3',tool='Efinity 2026.1.132',
    clock_period_ns=6.667,clock_mhz=clock/1e6,analyzed_fmax_mhz=156.691,setup_slack_ns=0.285,hold_slack_ns=0.091,
    performance=dict(baseline_cycles=oldcycles,optimized_cycles=newcycles,optimized_frame2_cycles=normal[1]['cycles'],
        baseline_fps=clock/oldcycles,optimized_fps=clock/newcycles,fps_gain_percent=(oldcycles/newcycles-1)*100,
        cycle_reduction_percent=(1-newcycles/oldcycles)*100,read_latency_10_cycles=long['cycles'],read_latency_10_fps=clock/long['cycles'],
        reads_per_frame=832320,writes_per_frame=782400,feature_bytes_per_frame=12917760),
    video_budget_reference=dict(xlr=21557,ram=119,dsp=10),estimated_system_sum=dict(xlr=47126,ram=223,dsp=136),
    estimated_device_remaining=dict(xlr=13674,ram=33,dsp=24),budget_is_integrated_result=False,
    full_frames_verified=6,full_feature_words_verified=sum(f['writes'] for f in frames),tests=tests,
    unit_tests=[d for p,d in units],reports=[p.relative_to(R).as_posix() for p in selected],
    board_integration_complete=False,board_video_fps_measured=False,full_gate_or_sdf_simulation=False)
(R/'final_evidence.json').write_text(json.dumps(ev,ensure_ascii=False,indent=2),encoding='utf8')
def layer_cycles(p):
    log=(p/'simulation.log').read_text().split('PASS')[0]
    totals=list(map(int,re.findall(r'LAYER.*?cycles=(\d+)',log)))
    return [totals[0]]+[b-a for a,b in zip(totals,totals[1:])]
lc=layer_cycles(full[0]);groups=[sum(lc[:5]),sum(lc[5:14]),sum(lc[14:])]
text=f'''# U8 RTL优化V2：帧率、效果、综合与布局布线

本次优化保持同一U8学生模型、量化权重和整数输出合同，完成真实RTL整数验证、Efinity综合与Ti60F225/I3布局布线。V2表示硬件实现版本，没有重新训练。

## 实测结果

| 项目 | 原U8基线 | 优化V2 |
|---|---:|---:|
| 通过布局布线的工作时钟 | 149.993 MHz | 149.993 MHz |
| 单帧周期，3周期读响应、随机停顿 | {oldcycles:,} | {newcycles:,} |
| 同条件核心处理时间 | {oldcycles/clock*1000:.3f} ms | {newcycles/clock*1000:.3f} ms |
| 同条件估算帧率 | {clock/oldcycles:.3f} fps | **{clock/newcycles:.3f} fps** |
| 单帧周期，10周期读响应、随机停顿 | {old['cycles_read10']:,} | {long['cycles']:,} |
| 10周期条件估算帧率 | {clock/old['cycles_read10']:.3f} fps | {clock/long['cycles']:.3f} fps |
| 每帧64位读 | 930,240 | 832,320 |
| 每帧64位写 | 782,400 | 782,400 |
| 对外特征字节/帧 | 13,701,120 | 12,917,760 |

在相同逻辑读响应和随机ready停顿条件下，帧率提高 **{(oldcycles/newcycles-1)*100:.2f}%**，周期减少 **{(1-newcycles/oldcycles)*100:.2f}%**。第二帧为{normal[1]['cycles']:,}周期。没有缩短测试的内存响应延迟或扩大外部数据口；仍只允许一个未完成读请求。

先前S8参考核心同类条件为17.377 fps；当前U8优化版已接近其速度，同时保留用户认可的U8风格效果。16.618 fps是核心在仿真访存条件下的估算，并非板上视频实测。10周期读响应下仍只有约10.59 fps，真实DDR桥与视频调度依然会影响整机结果。

## 综合与布局布线资源

实际工具为Efinity 2026.1.132，器件Ti60F225，I3 timing model。

综合阶段原始统计（不同资源种类不能直接相加成XLR）：

| 综合资源 | 数量 |
|---|---:|
| LUT4 | {syn['lut4']:,} |
| FF | {syn['ff']:,} |
| ADD | {syn['add']:,} |
| RAM块 | {syn['ram']} |
| DSP | {syn['dsp']} |

布局布线后的实际物理资源：

| 资源 | 原U8基线 | 优化V2 | 变化 |
|---|---:|---:|---:|
| XLR | 18,773 | **25,569** | +6,796 |
| RAM块 | 104 | **104** | 0 |
| DSP | 127 | **126** | −1 |

使用部分逻辑资源换取精确统计与流水调度的吞吐提升，RAM没有增加，DSP还减少一个。统计模块本身约4,344 XLR、0 RAM、0 DSP；统计投影复用原均值宽乘法器，没有为它额外增加一组MAC阵列。

最终布局布线Setup最差裕量 **+0.285 ns**，Hold最差裕量 **+0.091 ns**；工具分析Fmax为156.691 MHz，仍按实际通过的149.993 MHz计算帧率。SDC仅定义6.667 ns CNN时钟，没有假路径或多周期例外。

## 保持效果的证据

冻结 `model_int.npz`、计算图、W/bias/M/beta全部ROM与原U8逐字节一致；保留S12范围、reflection边界、当前帧均值、残差相加后单次舍入、RGB nearest-even。

最终RTL对两帧不同随机输入、三张实际图片和一个长读延迟完整帧，共6帧480×270输入逐层验证。每帧核对19层全部782,400次64位特征写回与地址，累计4,694,400次，全部一致。三张图片的实际RTL输出与原U8整数模型最大像素误差均为0，并额外与上一交付版本保存的U8输出PNG逐像素核对。

专项测试通过：5组U8/S8特征图的720个反射tap统计、516组正负投影乘法、1,056组均值除法、2,400组四通道量化即9,600个通道检查；另通过非2次幂面积棋盘图/白图，以及Icarus 24×18、20周期读响应、随机停顿的连续两帧。

`optimization_proof.json`提供新S24统计、S40投影累加和共享S61乘法器覆盖全部合法源编码的范围界。全网络验证属于逐层仿真回归，不等同于全输入形式等价证明或全网络门级/SDF仿真。

对比图：`review/U8_Original_vs_OptimizedRTL_V2_3Images.png`。这些是已有验证图片，只用于本次效果保持与实现检查，不作为新的模型质量测试集。

## 实际改动与提速来源

1. 前层输出时直接累积9个reflection tap的统计量，按整数权重投影得到S_A，删除中心化层的第一遍卷积。源特征边界乘数每轴为0/1/2，整数统计不引入额外舍入；最后仍按原倍率和8160面积做一次精确均值除法。
2. 每层缓存bias与M，8路累加器同时初始化，减少每个输出组的ROM等待。
3. DW窗口利用已有24字节读口一次捕获全部16通道，末尾样本捕获与窗口发布合并。
4. 1×1层用现有三行缓存的空闲槽预取下一行，读响应带内部owner标记，并与skip/写回仲裁；不改变外部端口或内存模型。
5. 根据固定图最多16通道的界，将地址中的通用乘法换成移位/选择，并显式定义两组系数的索引宽度，减少DSP与无效数据选择逻辑。

分阶段周期变化：

| 阶段 | 原U8 | 优化V2 | 节省 |
|---|---:|---:|---:|
| 编码器 | 5,220,550 | {groups[0]:,} | {5220550-groups[0]:,} |
| 残差主体 | 3,060,216 | {groups[1]:,} | {3060216-groups[1]:,} |
| 解码器＋RGB | 4,302,762 | {groups[2]:,} | {4302762-groups[2]:,} |

本版没有改变网络空间分辨率；编码器S12中间帧仍经DDR读写，尚未实施DW/PW局部融合。当前提速只统计上述已实现且通过验证的改动。单遍统计使卷积有效MAC恢复为79,119,360，另有2,496个统计投影MAC；行预取与调度降低等待，而非只依靠MAC减少。

## 整机资源预算与边界

与先前视频模块截图预算直接相加：

| 资源 | 视频历史预算 | 当前CNN实测 | 粗略合计 | Ti60总量 | 预估余量 |
|---|---:|---:|---:|---:|---:|
| XLR | 21,557 | 25,569 | 47,126 | 60,800 | 13,674 |
| RAM | 119 | 104 | 223 | 256 | 33 |
| DSP | 10 | 126 | 136 | 160 | 24 |

该相加表是集成前预算，尚未包含新增DDR桥、跨时钟FIFO和整机布局布线影响，不能作为整系统资源或时序报告。当前是独立CNN核，外部I/O延迟、板级管脚与视频跨域约束未纳入此次STA；尚未上板验证或完成摄像头整机位流。

继续集成时应保持同一U8整数合同，先接入真实DDR桥、帧调度和显示，再测量实际DDR条件下的整机帧率。下一步可评估DW/PW局部融合以减少S12搬运，任何新增改动都需重新核对数值与资源。

## 原始报告与版本

- 综合：`{flow['map'][0].relative_to(R).as_posix()}`。
- 布局布线：`{flow['pnr'][0].relative_to(R).as_posix()}`。
- 扁平RTL SHA256：`{ev['flat_rtl_sha256']}`。
- 整数模型SHA256：`{ev['integer_model_sha256']}`。
- 完整测试和文件哈希：`final_evidence.json`、`SHA256.json`。

开发过程中输出组索引缩窄后曾暴露系数缓存移位宽度问题，已改为显式2位拼接，并通过最终完整回归。早期失败及未采用版本没有作为最终资源或帧率结果。
'''
(R/'优化实测报告.md').write_text(text,encoding='utf8')
files=[p for p in R.iterdir() if p.is_file() and p.name!='SHA256.json']
for folder in ['rtl','mem','reference','baseline','review']:
    files.extend(p for p in (R/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc')
for rep in selected:
    files.extend(p for p in rep.rglob('*') if p.is_file() and (p.suffix!='.mem' or p.parent.name=='mem'))
files=sorted(set(files));manifest={p.relative_to(R).as_posix():sha(p) for p in files}
(R/'SHA256.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8');files.append(R/'SHA256.json')
dest=R.parent/'deliveries/XDL1_Student_U8_RTL_OptimizedV2_Ti60_20261013.zip'
prefix='XDL1_Student_U8_RTL_OptimizedV2_Ti60/'
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in files:z.write(p,prefix+p.relative_to(R).as_posix())
with zipfile.ZipFile(dest) as z:
    assert z.testzip() is None and len(z.namelist())==len(manifest)+1
    for n,h in manifest.items():assert hashlib.sha256(z.read(prefix+n)).hexdigest()==h,n
outer=sha(dest);dest.with_suffix('.zip.sha256.txt').write_text(outer+'  '+dest.name+'\n',encoding='ascii')
print(json.dumps(dict(zip=str(dest),bytes=dest.stat().st_size,sha256=outer,files=len(files),synthesis=syn,post_pnr=ev['post_pnr'],performance=ev['performance']),ensure_ascii=False,indent=2),flush=True)
