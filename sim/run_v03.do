# =============================================================================
# ArtFlow v03 仿真回归（ModelSim / QuestaSim）
# 用法（Transcript 里）：
#   cd D:/work/FPGA/ArtFlow/ArtFlow/sim
#   do run_v03.do          ;# 快速回归：v02 两个测试 + 2x2 合并单元测试 + 160x40 端到端（4 种 Bayer 相位）
#   do run_v03.do full     ;# 另外再跑 1920x1080 全分辨率端到端逐像素比对（本机约 5 分钟）
# 全部自检，看 Transcript 里的 PASS / FAIL。
# 需要 python（生成黄金数据；纯 Python，无第三方库）。
# =============================================================================
set FULL 0
if {$argc > 0} { if {$1 == "full"} { set FULL 1 } }

# ---------------------------------------------------------------- 黄金数据
exec python ../tools/v03_golden.py gen --w 64  --h 16  --out unit
exec python ../tools/v03_golden.py gen --w 160 --h 40  --out small
if {$FULL} { exec python ../tools/v03_golden.py gen --w 1920 --h 1080 --out full }

# ---------------------------------------------------------------- 编译
if {[file exists work]} { vdel -lib work -all }
vlib work

vlog ../rtl/true_dual_port_ram.v
vlog ../rtl/gamma_conrrection/gamma_correction.v
vlog ../rtl/gamma_conrrection/gamma_lut.v
vlog ../rtl/video/test_pattern.v
vlog ../rtl/video/bayer_bin2x2.v
vlog ../rtl/video/cam_fb_pipe.v
set FB ../rtl/frame_buffer
foreach f {DC_FIFO rst_n_piple frame_info_det ser2par_16_128_v1 ser2par_24_128_v1 ser2par_32_128_v1
           ser2par_64_128_v1 vid_rx_align_v1 ddr_wr_buffer ddr_rd_buffer bank_switch ddr_buffer
           par2ser_128_16_v1 par2ser_128_24_v1 par2ser_128_32_v1 par2ser_parse data_tx frame_buffer} {
    vlog $FB/$f.v
}
vlog tb_gamma_lut.v
vlog tb_test_pattern.v
vlog tb_bayer_bin2x2.v
vlog -sv axi_mem_model.sv tb_v03_pipe.sv

# ---------------------------------------------------------------- 运行
vsim -c -onfinish stop work.tb_gamma_lut
run -all
quit -sim

vsim -c -onfinish stop work.tb_test_pattern
run -all
quit -sim

vsim -c -onfinish stop work.tb_bayer_bin2x2
run -all
quit -sim

foreach ph {0 1 2 3} {
    vsim -c -onfinish stop -GPHASE=$ph work.tb_v03_pipe
    run -all
    quit -sim
}
echo [exec python ../tools/v03_golden.py check --w 160 --h 40 --out small --phase 3]

if {$FULL} {
    vsim -c -onfinish stop -GW=1920 -GH=1080 -GPREFIX=full -GGAP_PCT=10 -GVBLANK=20000 -GNGOOD=2 -GMAXFRM=10 work.tb_v03_pipe
    run -all
    quit -sim
    echo [exec python ../tools/v03_golden.py check --w 1920 --h 1080 --out full]
}
