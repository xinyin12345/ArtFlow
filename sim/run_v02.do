# ArtFlow v02 仿真脚本（ModelSim / QuestaSim）
# 用法：在 ModelSim 里  cd D:/work/FPGA/ArtFlow/ArtFlow/sim  然后  do run_v02.do
# 两个测试都是自检的，看 Transcript 里的 PASS / FAIL 即可

if {[file exists work]} { vdel -lib work -all }
vlib work

vlog ../rtl/true_dual_port_ram.v
vlog ../rtl/gamma_conrrection/gamma_correction.v
vlog ../rtl/gamma_conrrection/gamma_lut.v
vlog ../rtl/video/test_pattern.v
vlog tb_gamma_lut.v
vlog tb_test_pattern.v

vsim -c work.tb_gamma_lut
run -all
quit -sim

vsim -c work.tb_test_pattern
run -all
quit -sim
