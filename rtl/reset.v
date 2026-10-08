/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2020 Efinix Inc. All rights reserved.
//
// Description:
// System Reset Control  
//
// Language:  Verilog 2001
//
// ------------------------------------------------------------------------------
/////////////////////////////////////////////////////////////////////////////////

module reset_ctrl
#(
	parameter	NUM_RST			= 1,
	parameter	CYCLE			= 1,
	parameter	IN_RST_ACTIVE	= 1'b1,
	parameter	OUT_RST_ACTIVE	= 1'b1
)
(
	input	[NUM_RST-1:0]	i_arst,
	input	[NUM_RST-1:0]	i_clk,
	output	[NUM_RST-1:0]	o_srst
);

genvar i;
generate
	for (i=0; i<NUM_RST; i=i+1)
	begin
		if (IN_RST_ACTIVE & (1'b1 << i))
		begin
			if (OUT_RST_ACTIVE & (1'b1 << i))
			begin
				reset
				#(
					.IN_RST_ACTIVE	("HIGH"),
					.OUT_RST_ACTIVE	("HIGH"),
					.CYCLE			(CYCLE)
				)
				inst_sysclk_rstn
				(
					.i_arst	(i_arst[i]),
					.i_clk	(i_clk[i]),
					.o_srst	(o_srst[i])
				);
			end
			else
			begin
				reset
				#(
					.IN_RST_ACTIVE	("HIGH"),
					.OUT_RST_ACTIVE	("LOW"),
					.CYCLE			(CYCLE)
				)
				inst_sysclk_rstn
				(
					.i_arst	(i_arst[i]),
					.i_clk	(i_clk[i]),
					.o_srst	(o_srst[i])
				);
			end
		end
		else
		begin
			if (OUT_RST_ACTIVE & (1'b1 << i))
			begin
				reset
				#(
					.IN_RST_ACTIVE	("LOW"),
					.OUT_RST_ACTIVE	("HIGH"),
					.CYCLE			(CYCLE)
				)
				inst_sysclk_rstn
				(
					.i_arst	(i_arst[i]),
					.i_clk	(i_clk[i]),
					.o_srst	(o_srst[i])
				);
			end
			else
			begin
				reset
				#(
					.IN_RST_ACTIVE	("LOW"),
					.OUT_RST_ACTIVE	("LOW"),
					.CYCLE			(CYCLE)
				)
				inst_sysclk_rstn
				(
					.i_arst	(i_arst[i]),
					.i_clk	(i_clk[i]),
					.o_srst	(o_srst[i])
				);
			end
		end
	end
endgenerate

endmodule


module reset
#(
	parameter	IN_RST_ACTIVE	= "LOW",
	parameter	OUT_RST_ACTIVE	= "HIGH",
	parameter	CYCLE			= 1
)
(
	input	i_arst,
	input	i_clk,

	output	o_srst
);

reg		[CYCLE-1:0]r_srst_1P;

genvar i;
generate
	if (IN_RST_ACTIVE == "LOW")
	begin
		if (OUT_RST_ACTIVE == "LOW")
		begin
			always@(negedge i_arst or posedge i_clk)
			begin
				if (~i_arst)
					r_srst_1P[0]	<= 1'b0;
				else
					r_srst_1P[0]	<= 1'b1;
			end
			
			for (i=0; i<CYCLE-1; i=i+1)
			begin
				always@(negedge i_arst or posedge i_clk)
				begin
					if (~i_arst)
						r_srst_1P[i+1]	<= 1'b0;
					else
						r_srst_1P[i+1]	<= r_srst_1P[i];
				end
			end
		end
		else
		begin
			always@(negedge i_arst or posedge i_clk)
			begin
				if (~i_arst)
					r_srst_1P[0]	<= 1'b1;
				else
					r_srst_1P[0]	<= 1'b0;
			end
			
			for (i=0; i<CYCLE-1; i=i+1)
			begin
				always@(negedge i_arst or posedge i_clk)
				begin
					if (~i_arst)
						r_srst_1P[i+1]	<= 1'b1;
					else
						r_srst_1P[i+1]	<= r_srst_1P[i];
				end
			end
		end
	end
	else
	begin
		if (OUT_RST_ACTIVE == "LOW")
		begin
			always@(posedge i_arst or posedge i_clk)
			begin
				if (i_arst)
					r_srst_1P[0]	<= 1'b0;
				else
					r_srst_1P[0]	<= 1'b1;
			end
			
			for (i=0; i<CYCLE-1; i=i+1)
			begin
				always@(posedge i_arst or posedge i_clk)
				begin
					if (i_arst)
						r_srst_1P[i+1]	<= 1'b0;
					else
						r_srst_1P[i+1]	<= r_srst_1P[i];
				end
			end
		end
		else
		begin
			always@(posedge i_arst or posedge i_clk)
			begin
				if (i_arst)
					r_srst_1P[0]	<= 1'b1;
				else
					r_srst_1P[0]	<= 1'b0;
			end
			
			for (i=0; i<CYCLE-1; i=i+1)
			begin
				always@(posedge i_arst or posedge i_clk)
				begin
					if (i_arst)
						r_srst_1P[i+1]	<= 1'b1;
					else
						r_srst_1P[i+1]	<= r_srst_1P[i];
				end
			end
		end
	end
endgenerate

assign	o_srst	= r_srst_1P[CYCLE-1];

endmodule

// ArtFlow camera RX reset sequence. This module shares a source file with the
// existing resets so the user's Efinity project XML stays byte-for-byte intact.
// Assertion does not require any clock. Release follows core -> HS byte ->
// pixel, each through three local edges. A stopped discontinuous byte clock
// holds the byte/pixel datapaths in reset; the core/PHY can start independently
// and enable the clock lane. Never make PHY release depend on that byte clock.
// The firmware holds CAMERA reset for 20 ms and waits 50 ms after releasing it
// before configuring/starting the sensor; the vendor tINIT remains 100 us.
module artflow_csi_reset (
    input wire request_n,
    input wire core_clk,
    input wire byte_clk,
    input wire pixel_clk,
    output wire core_reset_n,
    output wire byte_reset_n,
    output wire pixel_reset_n,
    output wire phy_reset
);
(* async_reg = "true" *) reg [2:0] core_release = 3'b000;
(* async_reg = "true" *) reg [2:0] byte_release = 3'b000;
(* async_reg = "true" *) reg [2:0] pixel_release = 3'b000;
always @(posedge core_clk or negedge request_n) begin
    if (!request_n) core_release <= 3'b000;
    else core_release <= {core_release[1:0],1'b1};
end
always @(posedge byte_clk or negedge core_reset_n) begin
    if (!core_reset_n) byte_release <= 3'b000;
    else byte_release <= {byte_release[1:0],1'b1};
end
always @(posedge pixel_clk or negedge byte_reset_n) begin
    if (!byte_reset_n) pixel_release <= 3'b000;
    else pixel_release <= {pixel_release[1:0],1'b1};
end
assign core_reset_n = core_release[2];
assign byte_reset_n = byte_release[2];
assign pixel_reset_n = pixel_release[2];
assign phy_reset = ~core_reset_n;
endmodule
