"""Publish a review-only glass bitstream after source, timing, CDC and pixel gates."""
from pathlib import Path
import argparse,json,shutil,subprocess,sys
from PIL import Image,ImageDraw,ImageFont
from check_glass_project import R,sha,implementation_sources
from check_glass_implementation import main as check_implementation
EXPECTED_INDEX='AC64C44775640AE0551BE6E6462CB6DBA572369222B6F34A2064A9DC770CB14D'
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--activate',action='store_true');ap.add_argument('--delivery',type=Path);args=ap.parse_args()
    check_implementation()
    w=R/'work/glass_int8';o=R/'outputs/glass_int8';o.mkdir(exist_ok=True)
    reg=json.loads((w/'regression.json').read_text());assert reg['status']=='PASS'
    dirs=['full_system_final_960x540_example','final_black_32x30_black','final_white_32x30_white',
          'final_checker_32x30_checker','final_stress_32x28_random']+[f'final_fault{i}_32x28_random' for i in range(1,5)]
    cases=[]
    for d in dirs:
        s=json.loads((w/d/'summary.json').read_text());assert s['status']=='PASS',d
        for n,h in s['source_sha256'].items():assert sha(R/n)==h,'Stale simulation '+d+': '+n
        for n,h in s['evidence_sha256'].items():assert sha(w/d/n)==h,'Changed evidence '+d+': '+n
        cases.append(dict(name=d,args=s['args'],frames=len(s['frame_cycles']),feature_words=s['feature_words'],
                          cycles=s['frame_cycles'],seconds=s['seconds']))
    full=json.loads((w/dirs[0]/'summary.json').read_text())
    assert len(full['frame_cycles'])==2 and full['feature_words']==1190400
    assert sha(R/'.git/index').upper()==EXPECTED_INDEX,'Git index changed: review, do not reset it'
    impl=json.loads((w/'implementation_summary.json').read_text())
    for ext in ['bit','hex']:shutil.copy2(w/f'efinity_out/ArtFlow.{ext}',o/f'ArtFlow_glass_int8.{ext}')
    evidence=o/'evidence';evidence.mkdir(exist_ok=True)
    for name in ['implementation_summary.json','implementation_source_sha256.json','regression.json',
                 'video_cdc_summary.json','ui_cdc_summary.json','cnn_cdc_summary.json']:shutil.copy2(w/name,evidence/name)
    for name in ['ArtFlow.map.rpt','ArtFlow.place.rpt','ArtFlow.timing.rpt']:shutil.copy2(w/'efinity_out'/name,evidence/name)
    for d in dirs:
        target=evidence/d;target.mkdir(exist_ok=True)
        for name in ['summary.json','simulation.log']:shutil.copy2(w/d/name,target/name)
    for name in ['input.png','integer_output.png','rtl_output.png']:shutil.copy2(w/dirs[0]/name,o/name)
    im1=Image.open(o/'input.png').convert('RGB');im2=Image.open(o/'rtl_output.png').convert('RGB')
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',21);small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
    canvas=Image.new('RGB',(1008,378),'#f4f6f8');draw=ImageDraw.Draw(canvas)
    draw.text((20,13),'模型输入 480 × 270',font=font,fill='#142433')
    draw.text((520,13),'FPGA RTL 仿真输出 · Glass INT8',font=font,fill='#142433')
    canvas.paste(im1,(16,52));canvas.paste(im2,(512,52))
    draw.text((18,336),'22 层整数计算保持不变；RTL 与 TorchScript 参考逐字节一致。',font=small,fill='#146147')
    canvas.save(o/'glass_preview.png')
    if args.activate:
        shutil.copy2(R/'ArtFlow_glass.xml',R/'ArtFlow.xml')
        for ext in ['bit','hex']:shutil.copy2(o/f'ArtFlow_glass_int8.{ext}',R/f'outflow/ArtFlow.{ext}')
    manifest=dict(status='READY_FOR_BOARD_TEST',model='glass_5_20epochs_sum8192_480x270_input3x3_res32_r4_int8',
        project=str(R),activated=args.activate,board_programmed=False,git_commit_created=False,git_index_sha256=sha(R/'.git/index'),
        input_size=[480,270],display_size=[960,540],cnn_mhz=1000/7,axi_mhz=100,
        model_parameters_unchanged=True,implementation=impl,cases=cases,frames=sum(c['frames'] for c in cases),
        full_frame_cycles_100mhz=full['frame_cycles'],simulation_fps_min=full['fps_min'],
        bitstream_sha256=sha(o/'ArtFlow_glass_int8.bit'))
    (o/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
    fps=full['fps_min'];res=impl['resources'];slack=impl['minimum_slack_ns']
    report=f"""ArtFlow Glass INT8 模型集成试验
日期：2026-10-19
状态：READY_FOR_BOARD_TEST；未提交 Git；未下载到板卡。

工程：{R}
模型：{manifest['model']}
原始模型、权重、量化参数及网络计算图均未更改。
输入：480×270 RGB UINT8，内部反射补齐至 480×272。
输出：480×270，再由原工程双线性放大至 960×540。
沿用原相机、DDR、HDMI、RISC-V 控制及显示链路。
CNN 142.857 MHz，AXI/CPU 100 MHz。

实际布局布线结果
XLR：{res['xlr']['used']}/60800
RAM10：{res['ram10']['used']}/256
DSP：{res['dsp']['used']}/160
最差 setup：{slack['Setup (Max)']:+.3f} ns；hold：{slack['Hold (Min)']:+.3f} ns
Efinity 2026.1.132 的综合、布局布线、正常时序、位流生成均通过。
视频、UI、CNN 三类实际布线 CDC 检查均通过。

硬件实现
- 64 个共享乘加单元，八通道并行量化。
- 三行/五行缓存共用 6W 个 64 位字；特征图使用原 DDR 三个 2 MiB 槽。
- 12 个带中心化的残差层先统计卷积累加值，再重算并量化，
  精确实现 round_half_up(sum/8192)，避免保存全图宽累加器。
- 保留所有 INT8 特征、反射边界、5×5 输出卷积、残差系数、
  负数 round-half-up、限幅及 RGB 转换；没有降精度或重训练。
- 最终 RGB 位于 0x01800000，后处理读地址已同步调整。
- 使用模型保守范围证明检查 24 位卷积、40 位统计、48 位量化计算。

验证
仿真器：Questa Altera Starter FPGA Edition 2025.3。
{len(cases)} 组用例，共 {manifest['frames']} 帧。
完整尺寸连续两帧，每帧核对 1,190,400 个中间/最终 DDR 写字及其地址，
以及 518,400 个显示像素；RTL 输出与独立整数参考逐字节一致。
独立整数参考在完整尺寸下另与交付 TorchScript 模型逐字节一致。
黑、白、棋盘图案；60% 随机停顿；非整数时钟比连续三帧；
预处理与 CNN 阶段 AXI R/B 四类错误各两帧均通过。
该回归包含实际缩放、DDR 桥、异步 FIFO、仲裁及后台视频竞争。
完整尺寸两帧 100 MHz 墙钟周期：{full['frame_cycles']}
对应最低仿真处理速度：{fps:.3f} FPS。
这是 25% 总线随机停顿、12 周期读首拍延迟和后台视频争用下的仿真值，
不是板上测得的 PRC FPS。

查看效果
glass_preview.png：实际模型输入与 FPGA RTL 仿真输出对照。
ArtFlow_glass_int8.bit/.hex：通过上述门禁的候选位流。
manifest.json 和 evidence/：源文件哈希、测试日志、资源/时序与 CDC 证据。
当前主工程已切换 glass：{args.activate}。
原 U8 位流仍在 outputs/student_u8_optimized/；修改前文件及 outflow 位流
备份于 work/glass_int8/baseline/。Git 暂存区哈希与开始时一致。

复现（工程根目录，PowerShell）
D:/soft/Anaconda/envs/DL_latest/python.exe -B tools/generate_glass_int8.py
D:/soft/Anaconda/envs/DL_latest/python.exe -B tools/run_glass_int8.py --system --width 960 --height 540 --tag full_system_final --pattern example --video-load 1 --frames 2
D:/soft/Anaconda/envs/DL_latest/python.exe -B tools/run_glass_regression.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_glass_efinity.ps1 -Flow compile
D:/soft/Anaconda/envs/DL_latest/python.exe -B tools/package_glass_int8.py --activate

当前验证范围不包含上板观测、长期运行、门级 SDF 和真实 CPU/PLIC 启动长仿真。
"""
    (o/'集成与验证结果.txt').write_text(report,encoding='utf-8-sig')
    (R/'doc/glass_int8_results.txt').write_text(report,encoding='utf-8-sig')
    if args.activate:
        readme=R/'README_CODEX.md';old=readme.read_text(encoding='utf-8-sig')
        if '<!-- GLASS_TRIAL_END -->' in old:old=old.split('<!-- GLASS_TRIAL_END -->',1)[1].lstrip()
        header=f'''# ArtFlow Glass INT8 试验（未提交 Git）

当前主工程已切换到 glass_5 第 20 轮 22 层 INT8 模型，原始权重与整数计算规则保持不变。
480×270 输入，960×540 显示；CNN 142.857 MHz。实际布局布线 XLR 37,514/60,800、RAM10 227/256、DSP 125/160；正常时序和全部 CDC 通过。
完整尺寸两帧逐层/逐像素仿真通过，保守仿真处理速度 {fps:.3f} FPS，实板效果和 PRC FPS 待观察。
位流：outputs/glass_int8/ArtFlow_glass_int8.bit，已同步 outflow/ArtFlow.bit。
构建入口：tools/run_efinity.ps1 或 tools/run_glass_efinity.ps1；详情：doc/glass_int8_results.txt。
原 U8 文件保留，修改前活动配置与位流备份位于 work/glass_int8/baseline/。未自动下载板卡。

<!-- GLASS_TRIAL_END -->

'''
        readme.write_text(header+old,encoding='utf-8')

    if args.delivery:
        args.delivery.mkdir(parents=True,exist_ok=True)
        for name in ['ArtFlow_glass_int8.bit','ArtFlow_glass_int8.hex','glass_preview.png','input.png','rtl_output.png','manifest.json','集成与验证结果.txt']:
            shutil.copy2(o/name,args.delivery/name)
    print('GLASS READY_FOR_BOARD_TEST',fps,'FPS',o)
if __name__=='__main__':main()

