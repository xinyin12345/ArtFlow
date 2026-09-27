/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2020 Efinix Inc. All rights reserved.
//
// Description:
// A simple apb3 slave wrapper example design to interface with soc apb3
// signals
//
// Language:  Verilog 2001
//
// ------------------------------------------------------------------------------
// REVISION:
//  $Snapshot: $
//  $Id:$
//
// History:
// Custom Ports for TI60F225 Dev Kit OOB design 
// 
/////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

`define APB3_SLV_REG0_OFFSET   0  //constant ID
`define APB3_SLV_REG1_OFFSET   4  //LED control
`define APB3_SLV_REG2_OFFSET   8  //Streaming control
`define APB3_SLV_REG3_OFFSET   12 //RGB Gain Control
`define APB3_SLV_REG4_OFFSET   16 //Debug Register
`define APB3_SLV_REG5_OFFSET   20 //switch Input
`define APB3_SLV_REG6_OFFSET   24 //uvc status
`define APB3_SLV_REG7_OFFSET   28 //uvc control
`define APB3_SLV_REG8_OFFSET   32 //uvc x_start
`define APB3_SLV_REG9_OFFSET   36 //uvc x_end
`define APB3_SLV_REG10_OFFSET  40 //uvc y_start
`define APB3_SLV_REG11_OFFSET  44 //uvc y_end


module apb3_slave_oob #(
	// user parameter starts here
	//
	parameter	ADDR_WIDTH	= 12,
	parameter	DATA_WIDTH	= 32,
	parameter	NUM_REG		= 12
) (
	//apb3 port
	input				clk,
	input				resetn,
	input	[ADDR_WIDTH-1:0]	PADDR,
	input				PSEL,
	input				PENABLE,
	output				PREADY,
	input				PWRITE,
	input 	[DATA_WIDTH-1:0] 	PWDATA,
	output	[DATA_WIDTH-1:0] 	PRDATA,
	output				PSLVERROR,
	
	// user logic starts here
	//Input Ports		
	input 	[31:0]		i_id,					//Bit [31:0]		
	
	//Output Ports
	//Reg 0	LED Control
	output	[5:0]		o_LED,					//Bit [3:0]
	//Reg 1 Streaming control
	output 				o_start_dma_stream_in,	//Bit [0]
	output 				o_start_dma_stream_out,	//Bit [1]
	output 				o_uvc_resetn,			//Bit [2]

	//Reg 2 RGB Gain Control
	output 	[2:0]		o_red_gain,				//Bit [2:0]
	output 	[2:0]		o_green_gain,			//Bit [6:4]
	output 	[2:0]		o_blue_gain,			//Bit [10:8]
	
	//output				apb3MemoryStart,
	//output				apb3Interrupt,
	output 	[31:0] debug_reg,
	
	input	[5:0]		i_switch,
	input 	[2:0]		i_uvc_status,
	output 	[2:0]		o_uvc_control,
	
	output [12:0]	o_uvc_X_START,
	output [12:0]	o_uvc_X_WIN,
	output [12:0]	o_uvc_Y_START,
	output [12:0]	o_uvc_Y_WIN
	
	
	
);


///////////////////////////////////////////////////////////////////////////////

localparam [1:0]	IDLE   = 2'b00,
			SETUP  = 2'b01,
			ACCESS = 2'b10;

reg [1:0] 		busState, 
			busNext;
(* async_reg = "true",  syn_ramstyle = "registers" *)  reg [DATA_WIDTH-1:0]	slaveReg [0:NUM_REG-1];
reg [DATA_WIDTH-1:0]	slaveRegOut;
reg			slaveReady;
wire	 		actWrite,
			actRead;
integer			byteIndex;


///////////////////////////////////////////////////////////////////////////////

	always@(posedge clk or negedge resetn)
	begin
		if(!resetn) 
			busState <= IDLE; 
		else
			busState <= busNext; 
	end

	always@(*)
	begin
		busNext = busState;

		case(busState)
			IDLE:
			begin
				if(PSEL && !PENABLE)
					busNext = SETUP;
				else
					busNext = IDLE;
			end
			SETUP:
			begin
				if(PSEL && PENABLE)
					busNext = ACCESS;
				else
					busNext = IDLE;
			end
			ACCESS:
			begin
				if(PREADY)
					busNext = IDLE;
				else
					busNext = ACCESS;
			end
			default:
			begin
				busNext = IDLE;
			end
		endcase
	end


	assign actWrite = PWRITE  & (busState == ACCESS);
	assign actRead  = !PWRITE & (busState == ACCESS);
	assign PSLVERROR = 1'b0; //FIXME
	assign PRDATA = slaveRegOut;
	assign PREADY = slaveReady & & (busState !== IDLE);

	always@ (posedge clk)
	begin
		slaveReady <= actWrite | actRead;
	end

	always@ (posedge clk or negedge resetn)
	begin
		if(!resetn)
			for(byteIndex = 0; byteIndex < NUM_REG; byteIndex = byteIndex + 1)
			slaveReg[byteIndex] <= {{DATA_WIDTH}{1'b0}};
		else begin
			for(byteIndex = 0; byteIndex < NUM_REG; byteIndex = byteIndex + 1)
			if(actWrite && (PADDR[ADDR_WIDTH-1:0] == (byteIndex*4)))
				slaveReg[byteIndex] <= PWDATA;
			else
				slaveReg[byteIndex] <= slaveReg[byteIndex];
				
		end

	end

	always@ (posedge clk or negedge resetn)
	begin
		if(!resetn)
			slaveRegOut <= {{DATA_WIDTH}{1'b0}};
		else begin
			if(actRead)
			begin
				case(PADDR[6:2])
				6'd0  : slaveRegOut <= i_id;   		//Read Only
				6'd5  : slaveRegOut <= {26'd0,i_switch[5:0]};   		
				6'd6  : slaveRegOut <= {29'd0,i_uvc_status[2:0]};   		
				default: 
				begin 
					slaveRegOut <= slaveReg[PADDR[6:2]];
				end
				endcase
			end 
			else
			begin
				slaveRegOut <= slaveRegOut;
			end
		end

	end

	//custom logic starts here
	//assign apb3LED 		= slaveReg[0][0];
	//assign apb3MemoryStart 	= slaveReg[0][1];
	//assign apb3Interrupt 	= slaveReg[0][2];
	
	assign o_LED = slaveReg[1][5:0];
	assign o_start_dma_stream_in = slaveReg[2][0];
	assign o_start_dma_stream_out= slaveReg[2][1];
	assign o_uvc_resetn= slaveReg[2][2];
	
	assign o_red_gain   = slaveReg[3][2:0];
	assign o_green_gain = slaveReg[3][6:4];
	assign o_blue_gain  = slaveReg[3][10:8];
	assign debug_reg = slaveReg[4][31:0];

	assign o_uvc_control = slaveReg[7][2:0];
	
	assign o_uvc_X_START = slaveReg[8][12:0];
	assign o_uvc_X_WIN   = slaveReg[9][12:0];
	assign o_uvc_Y_START = slaveReg[10][12:0];
	assign o_uvc_Y_WIN   = slaveReg[11][12:0];
	
endmodule

//////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2013-2020 Efinix Inc. All rights reserved.
//
// This   document  contains  proprietary information  which   is
// protected by  copyright. All rights  are reserved.  This notice
// refers to original work by Efinix, Inc. which may be derivitive
// of other work distributed under license of the authors.  In the
// case of derivative work, nothing in this notice overrides the
// original author's license agreement.  Where applicable, the 
// original license agreement is included in it's original 
// unmodified form immediately below this header.
//
// WARRANTY DISCLAIMER.  
//     THE  DESIGN, CODE, OR INFORMATION ARE PROVIDED “AS IS” AND 
//     EFINIX MAKES NO WARRANTIES, EXPRESS OR IMPLIED WITH 
//     RESPECT THERETO, AND EXPRESSLY DISCLAIMS ANY IMPLIED WARRANTIES, 
//     INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF 
//     MERCHANTABILITY, NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR 
//     PURPOSE.  SOME STATES DO NOT ALLOW EXCLUSIONS OF AN IMPLIED 
//     WARRANTY, SO THIS DISCLAIMER MAY NOT APPLY TO LICENSEE.
//
// LIMITATION OF LIABILITY.  
//     NOTWITHSTANDING ANYTHING TO THE CONTRARY, EXCEPT FOR BODILY 
//     INJURY, EFINIX SHALL NOT BE LIABLE WITH RESPECT TO ANY SUBJECT 
//     MATTER OF THIS AGREEMENT UNDER TORT, CONTRACT, STRICT LIABILITY 
//     OR ANY OTHER LEGAL OR EQUITABLE THEORY (I) FOR ANY INDIRECT, 
//     SPECIAL, INCIDENTAL, EXEMPLARY OR CONSEQUENTIAL DAMAGES OF ANY 
//     CHARACTER INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF 
//     GOODWILL, DATA OR PROFIT, WORK STOPPAGE, OR COMPUTER FAILURE OR 
//     MALFUNCTION, OR IN ANY EVENT (II) FOR ANY AMOUNT IN EXCESS, IN 
//     THE AGGREGATE, OF THE FEE PAID BY LICENSEE TO EFINIX HEREUNDER 
//     (OR, IF THE FEE HAS BEEN WAIVED, $100), EVEN IF EFINIX SHALL HAVE 
//     BEEN INFORMED OF THE POSSIBILITY OF SUCH DAMAGES.  SOME STATES DO 
//     NOT ALLOW THE EXCLUSION OR LIMITATION OF INCIDENTAL OR 
//     CONSEQUENTIAL DAMAGES, SO THIS LIMITATION AND EXCLUSION MAY NOT 
//     APPLY TO LICENSEE.
//
/////////////////////////////////////////////////////////////////////////////
