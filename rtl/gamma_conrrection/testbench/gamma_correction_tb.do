vlib work

vlog gamma_correction_tb.v
vlog vga_gen.v
vlog true_dual_port_ram.v
vlog gamma_correction.v

vsim -t ps work.gamma_correction_tb

add wave -position insertpoint \
sim:/gamma_correction_tb/i_pclk \
sim:/gamma_correction_tb/w_sysclk_arstn \
sim:/gamma_correction_tb/w_x \
sim:/gamma_correction_tb/w_y \
sim:/gamma_correction_tb/w_valid \
sim:/gamma_correction_tb/w_de \
sim:/gamma_correction_tb/w_hs \
sim:/gamma_correction_tb/w_vs \
sim:/gamma_correction_tb/w_out_red \
sim:/gamma_correction_tb/w_out_green \
sim:/gamma_correction_tb/w_out_blue \
sim:/gamma_correction_tb/w_out_valid