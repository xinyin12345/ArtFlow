module i2c_master_reg_rom #(

    parameter ROM_SIZE                     = 25,   
    parameter TOTAL_ROM_DEPTH              = 256, // 6*7
    parameter ADDR_WIDTH                   = 8   // alt_clogb2(42) 
) (
    input  wire                  clock,
    input  wire [ADDR_WIDTH-1:0] addr_ptr,
    output wire [ROM_SIZE-1:0]   rdata_out
);

reg  [ROM_SIZE-1:0]   ROM [0:TOTAL_ROM_DEPTH-1];
wire [ROM_SIZE-1:0]   DATAA = {ROM_SIZE{1'b0}};
wire [ADDR_WIDTH-1:0] RADDR;
   
// initial begin
// 		//9134				//addr /data/read_en[1]
//     ROM[8'h00] = {16'h3002, 8'h01,1'b1 } ;////master start	
//     ROM[8'h01] = {16'h30eb, 8'h05,1'b0 };
//     ROM[8'h02] = {16'h30eb, 8'h0c,1'b0 };
//     ROM[8'h03] = {16'h300a, 8'hff,1'b0 };									
//     ROM[8'h04] = {16'h300b, 8'hff,1'b0 };			
//     ROM[8'h05] = {16'h30eb, 8'h05,1'b0 };												
//     ROM[8'h06] = {16'h30eb, 8'h09,1'b0 };
//     ROM[8'h07] = {16'h0114, 8'h01,1'b0 }; 
//     ROM[8'h08] = {16'h0128, 8'h00,1'b0 }; 							    
//     ROM[8'h09] = {16'h012a, 8'h18,1'b0 }; 
//     ROM[8'h0a] = {16'h012b, 8'h00,1'b0 }; 
//     ROM[8'h0b] = {16'h0160, 8'h04,1'b0 };
//     ROM[8'h0c] = {16'h0161, 8'h59,1'b0 };// fROM length
//     ROM[8'h0d] = {16'h0162, 8'h0d,1'b0 };//1920*1080
//     ROM[8'h0e] = {16'h0163, 8'h78,1'b0 };
//     ROM[8'h0f] = {16'h0164, 8'h00,1'b0 }; //x start position [15:8]
//     ROM[8'h10] = {16'h0165, 8'h20,1'b0 }; //x start position [7 :0]
//     ROM[8'h11] = {16'h0166, 8'h07,1'b0 }; //x end position [15:0]
//     ROM[8'h12] = {16'h0167, 8'ha0,1'b0 }; //x end position [7:0] x_end - x_start = 1920
//     ROM[8'h13] = {16'h0168, 8'h00,1'b0 }; //y start [15:8] 
//     ROM[8'h14] = {16'h0169, 8'h00,1'b0 }; //y start [7:0]
//     ROM[8'h15] = {16'h016a, 8'h04,1'b0 }; //y end [15:8] y_end - y_start = 1080 
//     ROM[8'h16] = {16'h016b, 8'h38,1'b0 }; //y end [7 :0]
//     ROM[8'h17] = {16'h016c, 8'h07,1'b0 }; //output image size x-direction [15:8]
//     ROM[8'h18] = {16'h016d, 8'h80,1'b0 }; //output image size x-direction [7:0]
//     ROM[8'h19] = {16'h016e, 8'h04,1'b0 }; //output image size (Y-direction)[15:8]
//     ROM[8'h1a] = {16'h016f, 8'h38,1'b0 }; //output image size (Y-direction)[7:0]
//     ROM[8'h1b] = {16'h0170, 8'h01,1'b0 };//Increment for odd pixels 1, 3 我理解如果是odd num.shoud compolimation to even num
//     ROM[8'h1c] = {16'h0171, 8'h01,1'b0 };
//     ROM[8'h1d] = {16'h0174, 8'h00,1'b0 };
//     ROM[8'h1e] = {16'h0175, 8'h00,1'b0 };
//     ROM[8'h1f] = {16'h018c, 8'h0a,1'b0 }; //raw10
//     ROM[8'h20] = {16'h018d, 8'h0a,1'b0 };
//     ROM[8'h21] = {16'h0301, 8'h05,1'b0 };
//     ROM[8'h22] = {16'h0303, 8'h01,1'b0 };
//     ROM[8'h23] = {16'h0304, 8'h03,1'b0 };
//     ROM[8'h24] = {16'h0305, 8'h03,1'b0 };
//     ROM[8'h25] = {16'h0306, 8'h00,1'b0 };
//     ROM[8'h26] = {16'h0307, 8'h60,1'b0 };
//     ROM[8'h27] = {16'h0309, 8'h0a,1'b0 };
//     ROM[8'h28] = {16'h030b, 8'h01,1'b0 };
//     ROM[8'h29] = {16'h030c, 8'h00,1'b0 };
//     ROM[8'h2a] = {16'h030d, 8'h72,1'b0 };
//     ROM[8'h2b] = {16'h0309, 8'h0a,1'b0 };
//     ROM[8'h2c] = {16'h030b, 8'h01,1'b0 };
//     ROM[8'h2d] = {16'h030c, 8'h00,1'b0 };
//     ROM[8'h2e] = {16'h030d, 8'h72,1'b0 };
//     ROM[8'h2f] = {16'h0100, 8'h01,1'b0 };
//     ROM[8'h30] = {16'h0157, 8'hd0,1'b0 };
//     ROM[8'h31] = {16'h0158, 8'h02,1'b0 };
//     ROM[8'h32] = {16'h0159, 8'h00,1'b0 };
//     ROM[8'h33] = {16'h0160, 8'h05,1'b0 };//07
//     ROM[8'h34] = {16'h0161, 8'hc8,1'b0 };//90 // fROM length
//     ROM[8'h35] = {16'h0162, 8'h0d,1'b0 };//0d
//     ROM[8'h36] = {16'h0163, 8'h78,1'b0 };//78
//     ROM[8'h37] = {16'h015a, 8'h04,1'b0 };
//     ROM[8'h38] = {16'h015b, 8'h6c,1'b0 };
//     ROM[8'h39] = {16'h025a, 8'h04,1'b0 };
//     ROM[8'h3a] = {16'h025b, 8'h6c,1'b0 };
//     ROM[8'h3b] = {16'h0172, 8'h03,1'b0 };
//     ROM[8'h3c] = {16'hffff, 8'hff,1'b0 };
      
// end 
initial begin
    
ROM[8'h00] = {16'h0100,8'h00,1'b0};
ROM[8'h01] = {16'h36e9,8'h80,1'b0};
ROM[8'h02] = {16'h37f9,8'h80,1'b0};
ROM[8'h03] = {16'h301f,8'h10,1'b0};
ROM[8'h04] = {16'h3058,8'h21,1'b0};
ROM[8'h05] = {16'h3059,8'h53,1'b0};
ROM[8'h06] = {16'h305a,8'h40,1'b0};
ROM[8'h07] = {16'h3250,8'h00,1'b0};
ROM[8'h08] = {16'h3301,8'h0c,1'b0};
ROM[8'h09] = {16'h3304,8'h50,1'b0};
ROM[8'h0a] = {16'h3305,8'h00,1'b0};
ROM[8'h0b] = {16'h3306,8'h50,1'b0};
ROM[8'h0c] = {16'h3307,8'h04,1'b0};
ROM[8'h0d] = {16'h3308,8'h0a,1'b0};
ROM[8'h0e] = {16'h3309,8'h60,1'b0};
ROM[8'h0f] = {16'h330b,8'hc8,1'b0};
ROM[8'h10] = {16'h330d,8'h08,1'b0};
ROM[8'h11] = {16'h330e,8'h38,1'b0};
ROM[8'h12] = {16'h331e,8'h41,1'b0};
ROM[8'h13] = {16'h331f,8'h51,1'b0};
ROM[8'h14] = {16'h3333,8'h10,1'b0};
ROM[8'h15] = {16'h3334,8'h40,1'b0};
ROM[8'h16] = {16'h3364,8'h5e,1'b0};
ROM[8'h17] = {16'h338e,8'he2,1'b0};
ROM[8'h18] = {16'h338f,8'h80,1'b0};
ROM[8'h19] = {16'h3390,8'h08,1'b0};
ROM[8'h1a] = {16'h3391,8'h18,1'b0};
ROM[8'h1b] = {16'h3392,8'hb8,1'b0};
ROM[8'h1c] = {16'h3393,8'h12,1'b0};
ROM[8'h1d] = {16'h3394,8'h14,1'b0};
ROM[8'h1e] = {16'h3395,8'h10,1'b0};
ROM[8'h1f] = {16'h3396,8'h88,1'b0};
ROM[8'h20] = {16'h3397,8'h98,1'b0};
ROM[8'h21] = {16'h3398,8'hb8,1'b0};
ROM[8'h22] = {16'h3399,8'h10,1'b0};
ROM[8'h23] = {16'h339a,8'h16,1'b0};
ROM[8'h24] = {16'h339b,8'h1c,1'b0};
ROM[8'h25] = {16'h339c,8'h40,1'b0};
ROM[8'h26] = {16'h33ac,8'h0a,1'b0};
ROM[8'h27] = {16'h33ad,8'h10,1'b0};
ROM[8'h28] = {16'h33ae,8'h4f,1'b0};
ROM[8'h29] = {16'h33af,8'h5e,1'b0};
ROM[8'h2a] = {16'h33b2,8'h50,1'b0};
ROM[8'h2b] = {16'h33b3,8'h10,1'b0};
ROM[8'h2c] = {16'h33f8,8'h00,1'b0};
ROM[8'h2d] = {16'h33f9,8'h50,1'b0};
ROM[8'h2e] = {16'h33fa,8'h00,1'b0};
ROM[8'h2f] = {16'h33fb,8'h50,1'b0};
ROM[8'h30] = {16'h33fc,8'h48,1'b0};
ROM[8'h31] = {16'h33fd,8'h78,1'b0};
ROM[8'h32] = {16'h349f,8'h03,1'b0};
ROM[8'h33] = {16'h34a6,8'h40,1'b0};
ROM[8'h34] = {16'h34a7,8'h58,1'b0};
ROM[8'h35] = {16'h34a8,8'h10,1'b0};
ROM[8'h36] = {16'h34a9,8'h10,1'b0};
ROM[8'h37] = {16'h34f8,8'h78,1'b0};
ROM[8'h38] = {16'h34f9,8'h10,1'b0};
ROM[8'h39] = {16'h3633,8'h44,1'b0};
ROM[8'h3a] = {16'h363b,8'h8f,1'b0};
ROM[8'h3b] = {16'h363c,8'h02,1'b0};
ROM[8'h3c] = {16'h3641,8'h08,1'b0};
ROM[8'h3d] = {16'h3654,8'h20,1'b0};
ROM[8'h3e] = {16'h3674,8'hc2,1'b0};
ROM[8'h3f] = {16'h3675,8'hb4,1'b0};
ROM[8'h40] = {16'h3676,8'h88,1'b0};
ROM[8'h41] = {16'h367c,8'h88,1'b0};
ROM[8'h42] = {16'h367d,8'hb8,1'b0};
ROM[8'h43] = {16'h3690,8'h34,1'b0};
ROM[8'h44] = {16'h3691,8'h44,1'b0};
ROM[8'h45] = {16'h3692,8'h54,1'b0};
ROM[8'h46] = {16'h3693,8'h88,1'b0};
ROM[8'h47] = {16'h3694,8'h98,1'b0};
ROM[8'h48] = {16'h3696,8'h80,1'b0};
ROM[8'h49] = {16'h3697,8'h83,1'b0};
ROM[8'h4a] = {16'h3698,8'h81,1'b0};
ROM[8'h4b] = {16'h3699,8'h81,1'b0};
ROM[8'h4c] = {16'h369a,8'h84,1'b0};
ROM[8'h4d] = {16'h369b,8'h82,1'b0};
ROM[8'h4e] = {16'h36a2,8'h80,1'b0};
ROM[8'h4f] = {16'h36a3,8'h88,1'b0};
ROM[8'h50] = {16'h36a4,8'hf8,1'b0};
ROM[8'h51] = {16'h36a5,8'hb8,1'b0};
ROM[8'h52] = {16'h36a6,8'h98,1'b0};
ROM[8'h53] = {16'h36d0,8'h15,1'b0};
ROM[8'h54] = {16'h36ea,8'h23,1'b0};
ROM[8'h55] = {16'h36eb,8'h0d,1'b0};
ROM[8'h56] = {16'h36ec,8'h65,1'b0};
ROM[8'h57] = {16'h36ed,8'h18,1'b0};
ROM[8'h58] = {16'h370f,8'h01,1'b0};
ROM[8'h59] = {16'h3722,8'h03,1'b0};
ROM[8'h5a] = {16'h3724,8'h92,1'b0};
ROM[8'h5b] = {16'h3727,8'h14,1'b0};
ROM[8'h5c] = {16'h37b0,8'h17,1'b0};
ROM[8'h5d] = {16'h37b1,8'h9b,1'b0};
ROM[8'h5e] = {16'h37b2,8'h9b,1'b0};
ROM[8'h5f] = {16'h37b3,8'h88,1'b0};
ROM[8'h60] = {16'h37b4,8'hb8,1'b0};
ROM[8'h61] = {16'h37fa,8'h23,1'b0};
ROM[8'h62] = {16'h37fb,8'h54,1'b0};
ROM[8'h63] = {16'h37fc,8'h21,1'b0};
ROM[8'h64] = {16'h37fd,8'h1c,1'b0};
ROM[8'h65] = {16'h391f,8'h41,1'b0};
ROM[8'h66] = {16'h3926,8'he0,1'b0};
ROM[8'h67] = {16'h3933,8'h80,1'b0};
ROM[8'h68] = {16'h3934,8'hf8,1'b0};
ROM[8'h69] = {16'h3935,8'h00,1'b0};
ROM[8'h6a] = {16'h3936,8'h45,1'b0};
ROM[8'h6b] = {16'h3937,8'h66,1'b0};
ROM[8'h6c] = {16'h3938,8'h66,1'b0};
ROM[8'h6d] = {16'h3939,8'h00,1'b0};
ROM[8'h6e] = {16'h393a,8'h03,1'b0};
ROM[8'h6f] = {16'h393b,8'h00,1'b0};
ROM[8'h70] = {16'h393c,8'h00,1'b0};
ROM[8'h71] = {16'h393d,8'h02,1'b0};
ROM[8'h72] = {16'h393e,8'h80,1'b0};
ROM[8'h73] = {16'h3e00,8'h01,1'b0};//00
ROM[8'h74] = {16'h3e01,8'hbb,1'b0};//ba
ROM[8'h75] = {16'h3e02,8'hf0,1'b0};//d0
ROM[8'h76] = {16'h3e16,8'h00,1'b0};
ROM[8'h77] = {16'h3e17,8'hc5,1'b0};
ROM[8'h78] = {16'h3e18,8'h00,1'b0};
ROM[8'h79] = {16'h3e19,8'hc5,1'b0};
ROM[8'h7a] = {16'h4509,8'h20,1'b0};
ROM[8'h7b] = {16'h450d,8'h0b,1'b0};
ROM[8'h7c] = {16'h5780,8'h76,1'b0};
ROM[8'h7d] = {16'h5784,8'h0a,1'b0};
ROM[8'h7e] = {16'h5785,8'h04,1'b0};
ROM[8'h7f] = {16'h5787,8'h0a,1'b0};
ROM[8'h80] = {16'h5788,8'h0a,1'b0};
ROM[8'h81] = {16'h5789,8'h08,1'b0};
ROM[8'h82] = {16'h578a,8'h0a,1'b0};
ROM[8'h83] = {16'h578b,8'h0a,1'b0};
ROM[8'h84] = {16'h578c,8'h08,1'b0};
ROM[8'h85] = {16'h578d,8'h40,1'b0};
ROM[8'h86] = {16'h5790,8'h08,1'b0};
ROM[8'h87] = {16'h5791,8'h04,1'b0};
ROM[8'h88] = {16'h5792,8'h04,1'b0};
ROM[8'h89] = {16'h5793,8'h08,1'b0};
ROM[8'h8a] = {16'h5794,8'h04,1'b0};
ROM[8'h8b] = {16'h5795,8'h04,1'b0};
ROM[8'h8c] = {16'h57ac,8'h00,1'b0};
ROM[8'h8d] = {16'h57ad,8'h00,1'b0};
ROM[8'h8e] = {16'h36e9,8'h53,1'b0};
ROM[8'h8f] = {16'h37f9,8'h53,1'b0};
ROM[8'h90] = {16'h0100,8'h01,1'b0};
ROM[8'h91] = {16'h3200,8'h00,1'b0};
ROM[8'h92] = {16'h3201,8'h00,1'b0};
ROM[8'h93] = {16'h3202,8'h00,1'b0};
ROM[8'h94] = {16'h3203,8'hb3,1'b0};
ROM[8'h95] = {16'h3204,8'h0a,1'b0};
ROM[8'h96] = {16'h3205,8'h07,1'b0};
ROM[8'h97] = {16'h3206,8'h04,1'b0};
ROM[8'h98] = {16'h3207,8'hf4,1'b0};
ROM[8'h99] = {16'h3208,8'h07,1'b0}; //0780
ROM[8'h9a] = {16'h3209,8'h80,1'b0};
ROM[8'h9b] = {16'h320a,8'h04,1'b0};//0438
ROM[8'h9c] = {16'h320b,8'h38,1'b0};
ROM[8'h9d] = {16'h3210,8'h01,1'b0};
ROM[8'h9e] = {16'h3211,8'h44,1'b0};
ROM[8'h9f] = {16'h3212,8'h00,1'b0};
ROM[8'ha0] = {16'h3213,8'h05,1'b0};
ROM[8'ha1] = {16'h3E08,8'h80,1'b0};
ROM[8'ha2] = {16'h3E09,8'h2a,1'b0};
ROM[8'ha3] = {16'h3221,8'h66,1'b0};
end 
// write is unused
wire [ADDR_WIDTH-1:0] ADDRA = {ADDR_WIDTH{1'b0}}; 
wire                  WEA   = 1'b0; 
always @ (posedge clock)
begin
    if (WEA) begin
        ROM[ADDRA] <= DATAA;
    end
end
   
assign RADDR = addr_ptr;
   
reg [ROM_SIZE-1:0] RDATA;
always @ (posedge clock)
begin
     RDATA <= ROM[RADDR];
end

assign rdata_out = RDATA;
   
endmodule			      