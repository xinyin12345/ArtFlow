`timescale 1ns/1ns

module gamma_correction_tb ();

parameter	MAX_HRES		= 12'd1024;
parameter	MAX_VRES		= 12'd512;
parameter	HSP				= 11'd44;
parameter	HBP				= 11'd148;
parameter	HFP				= 13'd88;
parameter	VSP				= 11'd5;
parameter	VBP				= 11'd36;
parameter	VFP				= 11'd4;
parameter	DATA_WIDTH		= 10;

reg	i_pclk;
reg	w_sysclk_arstn;

wire	[11:0]	w_x;
wire	[11:0]	w_y;
wire	w_valid;
wire	w_de;
wire	w_hs;
wire	w_vs;

wire	[DATA_WIDTH-1:0]	w_out_red;
wire	[DATA_WIDTH-1:0]	w_out_green;
wire	[DATA_WIDTH-1:0]	w_out_blue;
wire	w_out_valid;

initial
begin
   i_pclk = 1'b0;
   forever
      #2
      i_pclk = ~i_pclk;
end

initial
begin	
	w_sysclk_arstn	= 1'b0;
	
	#10
	w_sysclk_arstn = 1'b1;
end

vga_gen
#(
	.P_Cnt			(3'd1)
)
inst_fb_vga_gen_00
(
	.in_pclk		(i_pclk),
	.in_rstn		(w_sysclk_arstn),
	.H_SyncPulse	(HSP),
	.H_BackPorch	(HBP),
	.H_ActivePix	(MAX_HRES),
	.H_FrontPorch	(HFP),
	.V_SyncPulse	(VSP),
	.V_BackPorch	(VBP),
	.V_ActivePix	(MAX_VRES),
	.V_FrontPorch	(VFP),
	.in_en			(1'b1),
	
	.out_dbg_y		(),
	.out_x			(w_x	),
	.out_y   		(w_y	),
	.out_valid		(w_valid),
	.out_de			(w_de	),
	.out_hs			(w_hs	),
	.out_vs			(w_vs	)
);

gamma_correction
#(
	.DATA_WIDTH		(DATA_WIDTH),
	.GAMMA_CURVE	("2P4.mem")
)
inst_gamma_correction
(
	.i_pclk		(i_pclk),
	.i_rstn		(w_sysclk_arstn),
	
	.i_valid	(w_valid),
	.i_red		(w_x[DATA_WIDTH-1:0]),
	.i_green	(w_y[DATA_WIDTH-1:0]),
	.i_blue		(w_x[DATA_WIDTH-1:0] + w_y[DATA_WIDTH-1:0]),
	
	.o_red		(w_out_red		),
	.o_green	(w_out_green	),
	.o_blue		(w_out_blue		),
	.o_valid	(w_out_valid	)
);
endmodule
