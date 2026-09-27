# cd d:/FPGA_Prj/03_Ti60F225_DemoBoard/Prj_demo/frame_buffer
vlib work 

#vlog ./lpddr4_tb.v
#vlog ./axi_read.v
#vlog ./axi_write.v
#vlog ./ddr_wr_buffer.v
#vlog ./ddr_rd_buffer.v
#vlog ./memory_checker.v
#vlog ./DC_FIFO.v
#vlog ./axi_ram.v
#vlog ./ddr_buffer.v

#vlog ./rst_n_piple.v
vlog ./*.v


vsim -t ps  -voptargs=+acc work.lpddr4_tb

#virtual type { {4'b0000 IDLE} { 4'b0001 WRITE_ADDR} { 4'b0010 PRE_WRITE} { 4'b0011 WRITE} { 4'b0100 POST_WRITE}} state_type
#virtual function {(state_type)/checker0/u_ddr_buffer/u_axi_write/states} fsm_state

#virtual type { {4'b0000 IDLE} { 4'b0001 WRITE_ADDR} { 4'b0010 PRE_WRITE} { 4'b0011 WRITE} { 4'b0100 POST_WRITE}} nx_state
#virtual function {(nx_state)/checker0/u_ddr_buffer/u_axi_write/nstates} nxstate 
#add wave -color pink /u_mipi_dsi_rx/fsm_state 

#virtual type { {4'b0000 IDLE} { 4'b0001 READ_ADDR} { 4'b0010 READ}} rd_state_type
#virtual function {(rd_state_type)/checker0/u_ddr_buffer/u_axi_read/states} rd_state



do wave.do
run 20000us