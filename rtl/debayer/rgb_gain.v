module rgb_gain
#(
	parameter	P_DEPTH			= 10,
	parameter	PW				= 20
)
(
	input               i_pclk,
	input               i_arstn,
	
	input 		        i_hs,
	input               i_vs,
	input				i_de,
	input				i_valid,
	input [PW-1:0]  	i_data,
    input [2:0]         blue_gain,
    input [2:0]         green_gain,
    input [2:0]         red_gain,
	
	output  reg            	o_hs,
	output	reg				o_vs,
	output	reg				o_de,
	output	reg				o_valid,
	output  reg [PW-1:0]  	o_data
);

wire	[PW-1:0] 		w_data_filtered;
		
wire	[P_DEPTH:0] 	odd_line_byte_1;
wire	[P_DEPTH:0] 	odd_line_byte_0;
		

wire	[P_DEPTH-1:0] 	odd_line_pix_1;
wire	[P_DEPTH-1:0] 	odd_line_pix_0;
		
wire	[P_DEPTH:0] 	even_line_byte_1;
wire	[P_DEPTH:0] 	even_line_byte_0;
		

wire	[P_DEPTH-1:0] 	even_line_pix_1;
wire	[P_DEPTH-1:0] 	even_line_pix_0;
		
wire	[P_DEPTH-1:0] 	byte_1_div_1;
wire	[P_DEPTH-1:0] 	byte_1_div_2;
wire	[P_DEPTH-1:0] 	byte_1_div_4;
wire	[P_DEPTH-1:0] 	byte_0_div_1;
wire	[P_DEPTH-1:0] 	byte_0_div_2;
wire	[P_DEPTH-1:0] 	byte_0_div_4;

reg						r_line_cnt;

/* SYNC delay */
reg				r_de_1P;
reg				r_vs_1P;

always@(posedge i_pclk)
begin
	if (!i_arstn) begin
		r_de_1P		<= 1'b0;
		r_vs_1P		<= 1'b0;
	end else begin
		r_de_1P		<= i_de;
		r_vs_1P		<= i_vs;	
	end
end

always @( posedge i_pclk )
begin
	if( !i_arstn )
		r_line_cnt <= 'd0;
	else if (r_vs_1P && !i_vs)
		r_line_cnt	<= 1'b0;
	else if (r_de_1P && !i_de)
		r_line_cnt 	<= ~r_line_cnt;
end

/* RGB gain filter */   
assign byte_1_div_1 = i_data[P_DEPTH*2-1:P_DEPTH];//8bit of high
assign byte_1_div_2 = byte_1_div_1 >> 1;
assign byte_1_div_4 = byte_1_div_1 >> 2;
assign byte_0_div_1 = i_data[P_DEPTH-1:0]; //LSB 8 bits
assign byte_0_div_2 = byte_0_div_1 >> 1;
assign byte_0_div_4 = byte_0_div_1 >> 2;

 
// R Gr R Gr ===== 奇数行：R(低10bit) , Gr(高10bit) =====
assign odd_line_byte_1 = green_gain[2] ? 
          byte_1_div_1+(byte_1_div_2 & {P_DEPTH{green_gain[1]}})+(byte_1_div_4 & {P_DEPTH{green_gain[0]}}):
          byte_1_div_1-byte_1_div_4-(byte_1_div_2 & {P_DEPTH{~green_gain[1]}})-(byte_1_div_4 & {P_DEPTH{~green_gain[0]}});
assign odd_line_byte_0 = red_gain[2] ? 
          byte_0_div_1+(byte_0_div_2 & {P_DEPTH{red_gain[1]}})+(byte_0_div_4 & {P_DEPTH{red_gain[0]}}):
          byte_0_div_1-byte_0_div_4-(byte_0_div_2 & {P_DEPTH{~red_gain[1]}})-(byte_0_div_4 & {P_DEPTH{~red_gain[0]}});
// Gb B Gb B ===== 偶数行：Gb(低10bit) , B(高10bit) =====
assign even_line_byte_1 = blue_gain[2] ? 
          byte_1_div_1+(byte_1_div_2 & {P_DEPTH{blue_gain[1]}})+(byte_1_div_4 & {P_DEPTH{blue_gain[0]}}):
          byte_1_div_1-byte_1_div_4-(byte_1_div_2 & {P_DEPTH{~blue_gain[1]}})-(byte_1_div_4 & {P_DEPTH{~blue_gain[0]}});
assign even_line_byte_0 = green_gain[2] ? 
          byte_0_div_1+(byte_0_div_2 & {P_DEPTH{green_gain[1]}})+(byte_0_div_4 & {P_DEPTH{green_gain[0]}}):
          byte_0_div_1-byte_0_div_4-(byte_0_div_2 & {P_DEPTH{~green_gain[1]}})-(byte_0_div_4 & {P_DEPTH{~green_gain[0]}});

assign odd_line_pix_1 	= odd_line_byte_1[P_DEPTH] 	? {P_DEPTH{1'b1}} : odd_line_byte_1[P_DEPTH-1:0];
assign odd_line_pix_0 	= odd_line_byte_0[P_DEPTH] 	? {P_DEPTH{1'b1}} : odd_line_byte_0[P_DEPTH-1:0];
assign even_line_pix_1 	= even_line_byte_1[P_DEPTH] ? {P_DEPTH{1'b1}} : even_line_byte_1[P_DEPTH-1:0];
assign even_line_pix_0 	= even_line_byte_0[P_DEPTH] ? {P_DEPTH{1'b1}} : even_line_byte_0[P_DEPTH-1:0];

assign w_data_filtered = r_line_cnt ? {odd_line_pix_1, odd_line_pix_0}:{even_line_pix_1,even_line_pix_0};



always @( posedge i_pclk )
begin
	o_hs	<= i_hs;
	o_de	<= i_de;
	o_vs	<= i_vs;
	o_valid	<= i_valid;
	o_data	<= w_data_filtered;	
end


endmodule
