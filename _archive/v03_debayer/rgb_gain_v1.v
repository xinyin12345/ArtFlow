module rgb_gain_v1
#(
	parameter	P_DEPTH			= 8,
	parameter	Q_WIDTH			= 16	// Q8.8定点
)
(
	input               i_pclk,
	input               i_arstn,

	input 		        i_hs,
	input               i_vs,
	input				i_de,
	input				i_valid,
	input [P_DEPTH*2-1:0]  		i_data,

	input [Q_WIDTH-1:0]	gain_r,
	input [Q_WIDTH-1:0]	gain_g,
	input [Q_WIDTH-1:0]	gain_b,

	output  reg            	o_hs,
	output	reg				o_vs,
	output	reg				o_de,
	output	reg				o_valid,
	output  reg [P_DEPTH*2-1:0]  	o_data
);

reg				r_hs_1P;
reg				r_de_1P;
reg				r_vs_1P;
reg				r_valid_1P;
reg						r_line_cnt;

//同步信号打一拍
always@(posedge i_pclk)
begin
	if (!i_arstn) begin
		r_hs_1P		<= 1'b0;
		r_de_1P		<= 1'b0;
		r_vs_1P		<= 1'b0;
		r_valid_1P	<= 1'b0;
	end else begin
		r_hs_1P		<= i_hs;
		r_de_1P		<= i_de;
		r_vs_1P		<= i_vs;
		r_valid_1P	<= i_valid;
	end
end

//行标记切换
always @( posedge i_pclk )
begin
	if( !i_arstn )
		r_line_cnt <= 'd0;
	else if (r_vs_1P && !i_vs)
		r_line_cnt	<= 1'b0;
	else if(r_valid_1P && r_de_1P && (!i_de))
		r_line_cnt 	<= ~r_line_cnt;
end

wire [P_DEPTH-1:0] pix_high = i_data[P_DEPTH*2-1:P_DEPTH];
wire [P_DEPTH-1:0] pix_low  = i_data[P_DEPTH-1:0];

reg [Q_WIDTH+P_DEPTH-1:0] mul_high;
reg [Q_WIDTH+P_DEPTH-1:0] mul_low;

//多路选择对应通道增益
always @(*) begin
	if(r_line_cnt) begin
		//奇数行 high=Gr(gain_g)  low=R(gain_r)
		mul_high = pix_high * gain_g;
		mul_low  = pix_low  * gain_r;
	end
	else begin
		//偶数行 high=B(gain_b)  low=Gb(gain_g)
		mul_high = pix_high * gain_b;
		mul_low  = pix_low  * gain_g;
	end
end

//Q8.8 右移8位 + 10bit饱和
wire [P_DEPTH-1:0] out_high = (|mul_high[Q_WIDTH+P_DEPTH-1:P_DEPTH+8] ) ? 2**P_DEPTH-1 : mul_high[P_DEPTH+8-1:8];
wire [P_DEPTH-1:0] out_low  = (|mul_low[Q_WIDTH+P_DEPTH-1:P_DEPTH+8]  ) ? 2**P_DEPTH-1 : mul_low[P_DEPTH+8-1:8];

wire [P_DEPTH*2-1:0] w_data_filtered = {out_high,out_low};

always @( posedge i_pclk )
begin
	o_hs	<= i_hs;//r_hs_1P;
	o_de	<= i_de;//r_de_1P;
	o_vs	<= i_vs;//r_vs_1P;
	o_valid	<= i_valid;//r_valid_1P;
	o_data	<= w_data_filtered;
end

endmodule