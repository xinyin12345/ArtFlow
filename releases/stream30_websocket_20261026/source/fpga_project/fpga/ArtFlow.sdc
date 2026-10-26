# PLL Constraints
#################
# PLL Constraints
#################

create_clock -period 2.500 -name tx_cal_clk_90edge [get_ports {tx_cal_clk_90edge}]
create_clock -period 2.500 -name sdram_clk [get_ports {sdram_clk}]
create_clock -period 2.500 -name rx_cal_clk [get_ports {rx_cal_clk}]
create_clock -period 2.500 -name tx_cal_clk [get_ports {tx_cal_clk}]
create_clock -period 10.000 -name clk_100m [get_ports {clk_100m}]
create_clock -period 13.468 -name vid_clk_dvi2 [get_ports {vid_clk_dvi2}]
create_clock -period 13.468 -name hdmi_tx_slow_clk [get_ports {hdmi_tx_slow_clk}]
create_clock -period 18.519 -name fb [get_ports {fb}]
create_clock -waveform {0.337 1.684} -period 2.694 -name hdmi_tx_fast_clk [get_ports {hdmi_tx_fast_clk}]
create_clock -period 7.000 -name cnn_clk [get_ports {cnn_clk}]
create_clock -period 10.000 -name core_clk [get_ports {core_clk}]
create_clock -period 20.000 -name i_mipi_rx_pclk [get_ports {i_mipi_rx_pclk}]


create_clock -period 10.000 -name i_cam_ck_CLKOUT [get_ports {i_cam_ck_CLKOUT}]

set_clock_groups -exclusive -group {core_clk} -group {cnn_clk} -group {tx_cal_clk} -group {vid_clk_dvi2 hdmi_tx_slow_clk hdmi_tx_fast_clk} -group {i_mipi_rx_pclk} -group {sdram_clk} -group {rx_cal_clk}

# v04 registered Gray CDC buses, including the MSB merged into the binary FF.
# Efinity 2026.1 omits these paths under the clock groups above. The post-route
# gate in run_efinity.ps1 audits these constraints with a generated SDC copy that
# omits clock groups, without changing implementation or normal STA constraints.
set_bus_skew -from [get_pins {u_video_pipe/u_store/capture_words*[*]~FF|CLK}] -to [get_pins {u_video_pipe/u_store/count_meta[*]~FF|D}] 2.500
set_bus_skew -from [get_pins {u_video_pipe/u_store/display_epoch*[*]~FF|CLK}] -to [get_pins {u_video_pipe/u_store/epoch_meta[*]~FF|D}] 2.500

# v05 bundled-data mailbox: the source holds the whole gain snapshot until
# a two-flop request crossing, pixel capture, and two-flop acknowledgement.
# Earliest capture is two 20 ns pixel periods after launch. Limit every data
# path and bus skew to 20 ns in the post-route CDC audit (clock groups omitted).
# MAP flattens the gain output FFs to camera_gain_{r,g,b}; all 48 direct D-pin
# connections were checked against the generated ArtFlow.map.v netlist.
set_bus_skew -from [get_pins {u_control/mailbox_*[*]~FF|CLK}] -to [get_pins {camera_gain_*[*]~FF|D}] 20.000




# GPIO Constraints
####################



# HSIO GPIO Constraints
#########################
create_clock -period 40.000 -name CLK_25M [get_ports {CLK_25M}]
# Existing USER_PLL reference, 27.0000 MHz in ArtFlow.peri.xml; no frequency change.
create_clock -period 37.037 -name CLK_27M [get_ports {CLK_27M}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~95}] -max 0.302 [get_ports {ddr_addr[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~95}] -min -0.140 [get_ports {ddr_addr[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~36}] -max 0.302 [get_ports {ddr_addr[1]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~36}] -min -0.140 [get_ports {ddr_addr[1]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~70}] -max 0.302 [get_ports {ddr_addr[2]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~70}] -min -0.140 [get_ports {ddr_addr[2]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~50~1}] -max 0.302 [get_ports {ddr_addr[3]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~50~1}] -min -0.140 [get_ports {ddr_addr[3]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~25}] -max 0.302 [get_ports {ddr_addr[4]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~25}] -min -0.140 [get_ports {ddr_addr[4]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~142~1}] -max 0.302 [get_ports {ddr_addr[5]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~142~1}] -min -0.140 [get_ports {ddr_addr[5]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~59}] -max 0.302 [get_ports {ddr_addr[6]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~59}] -min -0.140 [get_ports {ddr_addr[6]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~110}] -max 0.302 [get_ports {ddr_addr[7]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~110}] -min -0.140 [get_ports {ddr_addr[7]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~26}] -max 0.302 [get_ports {ddr_addr[8]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~26}] -min -0.140 [get_ports {ddr_addr[8]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~127}] -max 0.302 [get_ports {ddr_addr[9]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~127}] -min -0.140 [get_ports {ddr_addr[9]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~138}] -max 0.302 [get_ports {ddr_addr[10]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~138}] -min -0.140 [get_ports {ddr_addr[10]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~60}] -max 0.302 [get_ports {ddr_addr[11]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~60}] -min -0.140 [get_ports {ddr_addr[11]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~35}] -max 0.302 [get_ports {ddr_addr[12]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~35}] -min -0.140 [get_ports {ddr_addr[12]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~71}] -max 0.302 [get_ports {ddr_addr[13]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~71}] -min -0.140 [get_ports {ddr_addr[13]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~109}] -max 0.302 [get_ports {ddr_addr[14]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~109}] -min -0.140 [get_ports {ddr_addr[14]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~143~1}] -max 0.302 [get_ports {ddr_addr[15]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~143~1}] -min -0.140 [get_ports {ddr_addr[15]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~74~1}] -max 0.302 [get_ports {ddr_ba[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~74~1}] -min -0.140 [get_ports {ddr_ba[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~132~1}] -max 0.302 [get_ports {ddr_ba[1]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~132~1}] -min -0.140 [get_ports {ddr_ba[1]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~126}] -max 0.302 [get_ports {ddr_ba[2]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~126}] -min -0.140 [get_ports {ddr_ba[2]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~49}] -max 0.302 [get_ports {ddr_cas_n}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~49}] -min -0.140 [get_ports {ddr_cas_n}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~149}] -max 0.302 [get_ports {ddr_ck_lo ddr_ck_hi}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~149}] -min -0.140 [get_ports {ddr_ck_lo ddr_ck_hi}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~123~1}] -max 0.302 [get_ports {ddr_cke[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~123~1}] -min -0.140 [get_ports {ddr_cke[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~95~1}] -max 0.302 [get_ports {ddr_cs_n[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~95~1}] -min -0.140 [get_ports {ddr_cs_n[0]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~131~1}] -max 0.302 [get_ports {ddr_dm_lo[0] ddr_dm_hi[0]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~131~1}] -min -0.140 [get_ports {ddr_dm_lo[0] ddr_dm_hi[0]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~83~1}] -max 0.302 [get_ports {ddr_dm_lo[1] ddr_dm_hi[1]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~83~1}] -min -0.140 [get_ports {ddr_dm_lo[1] ddr_dm_hi[1]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~73~1}] -max 0.302 [get_ports {ddr_odt[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~73~1}] -min -0.140 [get_ports {ddr_odt[0]}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~48}] -max 0.302 [get_ports {ddr_ras_n}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~48}] -min -0.140 [get_ports {ddr_ras_n}]
# set_output_delay -clock <CLOCK> [-reference_pin <clkout_pad>] -max <MAX CALCULATION> [get_ports {ddr_reset_n}]
# set_output_delay -clock <CLOCK> [-reference_pin <clkout_pad>] -min <MIN CALCULATION> [get_ports {ddr_reset_n}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~94}] -max 0.302 [get_ports {ddr_we_n}]
set_output_delay -clock sdram_clk -reference_pin [get_ports {sdram_clk~CLKOUT~218~94}] -min -0.140 [get_ports {ddr_we_n}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~148~1}] -max 0.476 [get_ports {ddr_dq_in_lo[0] ddr_dq_in_hi[0]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~148~1}] -min 0.276 [get_ports {ddr_dq_in_lo[0] ddr_dq_in_hi[0]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~150~1}] -max 0.302 [get_ports {ddr_dq_out_lo[0] ddr_dq_out_hi[0]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~150~1}] -min -0.140 [get_ports {ddr_dq_out_lo[0] ddr_dq_out_hi[0]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~150~1}] -max 0.302 [get_ports {ddr_dq_oe[0]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~150~1}] -min -0.140 [get_ports {ddr_dq_oe[0]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~157~1}] -max 0.476 [get_ports {ddr_dq_in_lo[1] ddr_dq_in_hi[1]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~157~1}] -min 0.276 [get_ports {ddr_dq_in_lo[1] ddr_dq_in_hi[1]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~159~1}] -max 0.302 [get_ports {ddr_dq_out_lo[1] ddr_dq_out_hi[1]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~159~1}] -min -0.140 [get_ports {ddr_dq_out_lo[1] ddr_dq_out_hi[1]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~159~1}] -max 0.302 [get_ports {ddr_dq_oe[1]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~159~1}] -min -0.140 [get_ports {ddr_dq_oe[1]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~164~1}] -max 0.476 [get_ports {ddr_dq_in_lo[2] ddr_dq_in_hi[2]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~164~1}] -min 0.276 [get_ports {ddr_dq_in_lo[2] ddr_dq_in_hi[2]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~166~1}] -max 0.302 [get_ports {ddr_dq_out_lo[2] ddr_dq_out_hi[2]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~166~1}] -min -0.140 [get_ports {ddr_dq_out_lo[2] ddr_dq_out_hi[2]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~166~1}] -max 0.302 [get_ports {ddr_dq_oe[2]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~166~1}] -min -0.140 [get_ports {ddr_dq_oe[2]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~149~1}] -max 0.476 [get_ports {ddr_dq_in_lo[3] ddr_dq_in_hi[3]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~149~1}] -min 0.276 [get_ports {ddr_dq_in_lo[3] ddr_dq_in_hi[3]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~151~1}] -max 0.302 [get_ports {ddr_dq_out_lo[3] ddr_dq_out_hi[3]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~151~1}] -min -0.140 [get_ports {ddr_dq_out_lo[3] ddr_dq_out_hi[3]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~151~1}] -max 0.302 [get_ports {ddr_dq_oe[3]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~151~1}] -min -0.140 [get_ports {ddr_dq_oe[3]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~189~1}] -max 0.476 [get_ports {ddr_dq_in_lo[4] ddr_dq_in_hi[4]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~189~1}] -min 0.276 [get_ports {ddr_dq_in_lo[4] ddr_dq_in_hi[4]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~191~1}] -max 0.302 [get_ports {ddr_dq_out_lo[4] ddr_dq_out_hi[4]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~191~1}] -min -0.140 [get_ports {ddr_dq_out_lo[4] ddr_dq_out_hi[4]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~191~1}] -max 0.302 [get_ports {ddr_dq_oe[4]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~191~1}] -min -0.140 [get_ports {ddr_dq_oe[4]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~156~1}] -max 0.476 [get_ports {ddr_dq_in_lo[5] ddr_dq_in_hi[5]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~156~1}] -min 0.276 [get_ports {ddr_dq_in_lo[5] ddr_dq_in_hi[5]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~158~1}] -max 0.302 [get_ports {ddr_dq_out_lo[5] ddr_dq_out_hi[5]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~158~1}] -min -0.140 [get_ports {ddr_dq_out_lo[5] ddr_dq_out_hi[5]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~158~1}] -max 0.302 [get_ports {ddr_dq_oe[5]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~158~1}] -min -0.140 [get_ports {ddr_dq_oe[5]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~165~1}] -max 0.476 [get_ports {ddr_dq_in_lo[6] ddr_dq_in_hi[6]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~165~1}] -min 0.276 [get_ports {ddr_dq_in_lo[6] ddr_dq_in_hi[6]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~167~1}] -max 0.302 [get_ports {ddr_dq_out_lo[6] ddr_dq_out_hi[6]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~167~1}] -min -0.140 [get_ports {ddr_dq_out_lo[6] ddr_dq_out_hi[6]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~167~1}] -max 0.302 [get_ports {ddr_dq_oe[6]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~167~1}] -min -0.140 [get_ports {ddr_dq_oe[6]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~188~1}] -max 0.476 [get_ports {ddr_dq_in_lo[7] ddr_dq_in_hi[7]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~188~1}] -min 0.276 [get_ports {ddr_dq_in_lo[7] ddr_dq_in_hi[7]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~190~1}] -max 0.302 [get_ports {ddr_dq_out_lo[7] ddr_dq_out_hi[7]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~190~1}] -min -0.140 [get_ports {ddr_dq_out_lo[7] ddr_dq_out_hi[7]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~190~1}] -max 0.302 [get_ports {ddr_dq_oe[7]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~190~1}] -min -0.140 [get_ports {ddr_dq_oe[7]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~82~1}] -max 0.476 [get_ports {ddr_dq_in_lo[8] ddr_dq_in_hi[8]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~82~1}] -min 0.276 [get_ports {ddr_dq_in_lo[8] ddr_dq_in_hi[8]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~84~1}] -max 0.302 [get_ports {ddr_dq_out_lo[8] ddr_dq_out_hi[8]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~84~1}] -min -0.140 [get_ports {ddr_dq_out_lo[8] ddr_dq_out_hi[8]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~84~1}] -max 0.302 [get_ports {ddr_dq_oe[8]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~84~1}] -min -0.140 [get_ports {ddr_dq_oe[8]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~39~1}] -max 0.476 [get_ports {ddr_dq_in_lo[9] ddr_dq_in_hi[9]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~39~1}] -min 0.276 [get_ports {ddr_dq_in_lo[9] ddr_dq_in_hi[9]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~41~1}] -max 0.302 [get_ports {ddr_dq_out_lo[9] ddr_dq_out_hi[9]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~41~1}] -min -0.140 [get_ports {ddr_dq_out_lo[9] ddr_dq_out_hi[9]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~41~1}] -max 0.302 [get_ports {ddr_dq_oe[9]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~41~1}] -min -0.140 [get_ports {ddr_dq_oe[9]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~22~1}] -max 0.476 [get_ports {ddr_dq_in_lo[10] ddr_dq_in_hi[10]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~22~1}] -min 0.276 [get_ports {ddr_dq_in_lo[10] ddr_dq_in_hi[10]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~24~1}] -max 0.302 [get_ports {ddr_dq_out_lo[10] ddr_dq_out_hi[10]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~24~1}] -min -0.140 [get_ports {ddr_dq_out_lo[10] ddr_dq_out_hi[10]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~24~1}] -max 0.302 [get_ports {ddr_dq_oe[10]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~24~1}] -min -0.140 [get_ports {ddr_dq_oe[10]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~92~1}] -max 0.476 [get_ports {ddr_dq_in_lo[11] ddr_dq_in_hi[11]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~92~1}] -min 0.276 [get_ports {ddr_dq_in_lo[11] ddr_dq_in_hi[11]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~94~1}] -max 0.302 [get_ports {ddr_dq_out_lo[11] ddr_dq_out_hi[11]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~94~1}] -min -0.140 [get_ports {ddr_dq_out_lo[11] ddr_dq_out_hi[11]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~94~1}] -max 0.302 [get_ports {ddr_dq_oe[11]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~94~1}] -min -0.140 [get_ports {ddr_dq_oe[11]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~23~1}] -max 0.476 [get_ports {ddr_dq_in_lo[12] ddr_dq_in_hi[12]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~23~1}] -min 0.276 [get_ports {ddr_dq_in_lo[12] ddr_dq_in_hi[12]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~25~1}] -max 0.302 [get_ports {ddr_dq_out_lo[12] ddr_dq_out_hi[12]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~25~1}] -min -0.140 [get_ports {ddr_dq_out_lo[12] ddr_dq_out_hi[12]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~25~1}] -max 0.302 [get_ports {ddr_dq_oe[12]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~25~1}] -min -0.140 [get_ports {ddr_dq_oe[12]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~38~1}] -max 0.476 [get_ports {ddr_dq_in_lo[13] ddr_dq_in_hi[13]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~38~1}] -min 0.276 [get_ports {ddr_dq_in_lo[13] ddr_dq_in_hi[13]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~40~1}] -max 0.302 [get_ports {ddr_dq_out_lo[13] ddr_dq_out_hi[13]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~40~1}] -min -0.140 [get_ports {ddr_dq_out_lo[13] ddr_dq_out_hi[13]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~40~1}] -max 0.302 [get_ports {ddr_dq_oe[13]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~40~1}] -min -0.140 [get_ports {ddr_dq_oe[13]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~11~1}] -max 0.476 [get_ports {ddr_dq_in_lo[14] ddr_dq_in_hi[14]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~11~1}] -min 0.276 [get_ports {ddr_dq_in_lo[14] ddr_dq_in_hi[14]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~13~1}] -max 0.302 [get_ports {ddr_dq_out_lo[14] ddr_dq_out_hi[14]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~13~1}] -min -0.140 [get_ports {ddr_dq_out_lo[14] ddr_dq_out_hi[14]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~13~1}] -max 0.302 [get_ports {ddr_dq_oe[14]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~13~1}] -min -0.140 [get_ports {ddr_dq_oe[14]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~12~1}] -max 0.476 [get_ports {ddr_dq_in_lo[15] ddr_dq_in_hi[15]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~12~1}] -min 0.276 [get_ports {ddr_dq_in_lo[15] ddr_dq_in_hi[15]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~14~1}] -max 0.302 [get_ports {ddr_dq_out_lo[15] ddr_dq_out_hi[15]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~14~1}] -min -0.140 [get_ports {ddr_dq_out_lo[15] ddr_dq_out_hi[15]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~14~1}] -max 0.302 [get_ports {ddr_dq_oe[15]}]
set_output_delay -clock tx_cal_clk_90edge -reference_pin [get_ports {tx_cal_clk_90edge~CLKOUT~14~1}] -min -0.140 [get_ports {ddr_dq_oe[15]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~172~1}] -max 0.476 [get_ports {ddr_dqs_in_lo[0] ddr_dqs_in_hi[0]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~172~1}] -min 0.276 [get_ports {ddr_dqs_in_lo[0] ddr_dqs_in_hi[0]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~174~1}] -max 0.302 [get_ports {ddr_dqs_out_lo[0] ddr_dqs_out_hi[0]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~174~1}] -min -0.140 [get_ports {ddr_dqs_out_lo[0] ddr_dqs_out_hi[0]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~174~1}] -max 0.302 [get_ports {ddr_dqs_oe[0]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~174~1}] -min -0.140 [get_ports {ddr_dqs_oe[0]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~175~1}] -max 0.302 [get_ports {ddr_dqs_oe_n[0]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~175~1}] -min -0.140 [get_ports {ddr_dqs_oe_n[0]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~30~1}] -max 0.476 [get_ports {ddr_dqs_in_lo[1] ddr_dqs_in_hi[1]}]
set_input_delay -clock rx_cal_clk -reference_pin [get_ports {rx_cal_clk~CLKOUT~30~1}] -min 0.276 [get_ports {ddr_dqs_in_lo[1] ddr_dqs_in_hi[1]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~32~1}] -max 0.302 [get_ports {ddr_dqs_out_lo[1] ddr_dqs_out_hi[1]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~32~1}] -min -0.140 [get_ports {ddr_dqs_out_lo[1] ddr_dqs_out_hi[1]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~32~1}] -max 0.302 [get_ports {ddr_dqs_oe[1]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~32~1}] -min -0.140 [get_ports {ddr_dqs_oe[1]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~33~1}] -max 0.302 [get_ports {ddr_dqs_oe_n[1]}]
set_output_delay -clock tx_cal_clk -reference_pin [get_ports {tx_cal_clk~CLKOUT~33~1}] -min -0.140 [get_ports {ddr_dqs_oe_n[1]}]

# LVDS Tx Constraints
#######################
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~175}] -max 0.435 [get_ports {tmds_tx_clk_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~175}] -min -0.140 [get_ports {tmds_tx_clk_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~175}] -max 0.435 [get_ports {tmds_tx_clk_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~175}] -min -0.140 [get_ports {tmds_tx_clk_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~175}] -max 0.483 [get_ports {tmds_tx_clk_TX_RST}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~175}] -min -0.175 [get_ports {tmds_tx_clk_TX_RST}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~215}] -max 0.435 [get_ports {tmds_tx_data0_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~215}] -min -0.140 [get_ports {tmds_tx_data0_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~215}] -max 0.435 [get_ports {tmds_tx_data0_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~215}] -min -0.140 [get_ports {tmds_tx_data0_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~215}] -max 0.483 [get_ports {tmds_tx_data0_TX_RST}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~215}] -min -0.175 [get_ports {tmds_tx_data0_TX_RST}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~187}] -max 0.435 [get_ports {tmds_tx_data1_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~187}] -min -0.140 [get_ports {tmds_tx_data1_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~187}] -max 0.435 [get_ports {tmds_tx_data1_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~187}] -min -0.140 [get_ports {tmds_tx_data1_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~187}] -max 0.483 [get_ports {tmds_tx_data1_TX_RST}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~187}] -min -0.175 [get_ports {tmds_tx_data1_TX_RST}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~200}] -max 0.435 [get_ports {tmds_tx_data2_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~200}] -min -0.140 [get_ports {tmds_tx_data2_TX_DATA[*]}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~200}] -max 0.435 [get_ports {tmds_tx_data2_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~200}] -min -0.140 [get_ports {tmds_tx_data2_TX_OE}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~200}] -max 0.483 [get_ports {tmds_tx_data2_TX_RST}]
set_output_delay -clock hdmi_tx_slow_clk -reference_pin [get_ports {hdmi_tx_slow_clk~CLKOUT~218~200}] -min -0.175 [get_ports {tmds_tx_data2_TX_RST}]

# MIPI RX Lane Constraints
############################
# 
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -max 0.604 [get_ports {cam_d0_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -min 0.070 [get_ports {cam_d0_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -max 0.362 [get_ports {cam_d0_RST}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -min -0.140 [get_ports {cam_d0_RST}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -max 0.725 [get_ports {cam_d0_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -min 0.420 [get_ports {cam_d0_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -max 0.560 [get_ports {cam_d0_HS_IN[*]}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~82~322}] -min 0.325 [get_ports {cam_d0_HS_IN[*]}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -max 0.604 [get_ports {cam_d1_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -min 0.070 [get_ports {cam_d1_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -max 0.362 [get_ports {cam_d1_RST}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -min -0.140 [get_ports {cam_d1_RST}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -max 0.725 [get_ports {cam_d1_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -min 0.420 [get_ports {cam_d1_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -max 0.560 [get_ports {cam_d1_HS_IN[*]}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~130~322}] -min 0.325 [get_ports {cam_d1_HS_IN[*]}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -max 0.604 [get_ports {cam_d2_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -min 0.070 [get_ports {cam_d2_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -max 0.362 [get_ports {cam_d2_RST}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -min -0.140 [get_ports {cam_d2_RST}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -max 0.725 [get_ports {cam_d2_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -min 0.420 [get_ports {cam_d2_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -max 0.560 [get_ports {cam_d2_HS_IN[*]}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~73~322}] -min 0.325 [get_ports {cam_d2_HS_IN[*]}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -max 0.604 [get_ports {cam_d3_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -min 0.070 [get_ports {cam_d3_FIFO_RD}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -max 0.362 [get_ports {cam_d3_RST}]
set_output_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -min -0.140 [get_ports {cam_d3_RST}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -max 0.725 [get_ports {cam_d3_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -min 0.420 [get_ports {cam_d3_FIFO_EMPTY}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -max 0.560 [get_ports {cam_d3_HS_IN[*]}]
set_input_delay -clock i_cam_ck_CLKOUT -reference_pin [get_ports {i_cam_ck_CLKOUT~CLKOUT~141~322}] -min 0.325 [get_ports {cam_d3_HS_IN[*]}]




# v05 asynchronous serial inputs terminate in the generated SoC synchronizers.
# UART 115200 8N1 and camera I2C are verified at protocol level, not as synchronous I/O.
set_false_path -from [get_ports {uart_rx io_cam_scl_IN io_cam_sda_IN}]


# v06 asynchronous board buttons: only the first synchronization stage.
set_false_path -from [get_ports {key_mode_n}] -to [get_pins {u_ui/u_mode_key/key_meta~FF|D}]
set_false_path -from [get_ports {key_osd_n}] -to [get_pins {u_ui/u_osd_key/key_meta~FF|D}]

# Frame-stable layout payload: captured after synchronized display epoch.
# Output-register alias is promoted to top level in the implemented netlist.
set_bus_skew -from [get_pins {active_layout[*]~FF|CLK}] -to [get_pins {u_video_pipe/u_store/layout_meta[*]~FF|D}] 2.500

# KEY3 uses the same two-FF synchronization and 20 ms edge qualification.
set_false_path -from [get_ports {key_style_n}] -to [get_pins {u_video_pipe/u_accel_dma/styles.key_filter/key_meta~FF|D}]
# The SPI read engine samples its two-FF DO synchronizer only 8 CNN clocks
# after changing SCK. Audit the round trip separately against 56 ns; do not
# invent a phase-locked clock for this transaction-gated SCK signal.
set_false_path -from [get_ports {flash_miso}] -to [get_pins {u_video_pipe/u_accel_dma/styles.banks/reader/miso_meta~FF|D}]
set_max_delay 10.000 -to [get_ports {flash_cs_n flash_sck flash_mosi}]

# AFS stream: asynchronous READY and delayed-sampled MISO first stages only.
# Budget input routing separately; normal timing still checks stage1 -> stage2.
set_false_path -from [get_ports {stream_ready}] -to [get_pins {u_stream/packet/ready_meta~FF|D}]
set_false_path -from [get_ports {stream_miso}] -to [get_pins {u_stream/packet/miso_meta~FF|D}]
set_max_delay 10.000 -to [get_ports {stream_cs_n stream_sclk stream_mosi}]
