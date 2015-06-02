`include "dport.vh"

module regs(
	input wire clk,
	
	input wire [31:0] armaddr,
	output reg [31:0] armrdata,
	input wire [31:0] armwdata,
	input wire armwr,
	input wire armreq,
	output reg armack,
	input wire [3:0] armwstrb,
	output reg armerr,
	
	output reg [19:0] auxaddr,
	output reg [7:0] auxwdata,
	output reg auxreq,
	output reg auxwr,
	input wire auxack,
	input wire auxerr,
	input wire [7:0] auxrdata,
	
	output reg [15:0] debugaddr,
	output reg debugreq,
	input wire debugack,
	input wire [31:0] debugrdata,
	
	output reg [`ATTRMAX:0] attr,
	output reg reset,
	output reg [2:0] phymode,
	output reg [2:0] prbssel
);

	reg armreq0;
	reg [1:0] state;
	localparam IDLE = 0;
	localparam AUX = 1;
	localparam DEBUG = 2;

	initial begin
		reset = 1;
		attr = 0;
		phymode = 0;
		prbssel = 0;
		auxreq = 0;
		debugreq = 0;
	end
	always @(posedge clk) begin
		armack <= 0;
		armreq0 <= armreq;
		case(state)
		IDLE:
			if(armreq && !armreq0)
				casez(armaddr[23:20])
				0:
					if(armwr) begin
						armack <= 1;
						armerr <= 0;
						case(armaddr[19:0] & -4)
						'h00: begin
							reset <= !armwdata[31];
							prbssel <= armwdata[5:3];
							phymode <= armwdata[2:0];
						end
						'h40: attr[31:0] <= armwdata;
						'h44: attr[63:32] <= armwdata;
						'h48: attr[95:64] <= armwdata;
						'h4c: attr[127:96] <= armwdata;
						'h50: begin
							attr[143:128] <= armwdata[15:0];
							attr[208] <= armwdata[16];
						end
						'h54: attr[167:144] <= armwdata[23:0];
						'h58: attr[191:168] <= armwdata[23:0];
						'h5c: attr[207:192] <= armwdata[15:0];
						default: armack <= 0;
						endcase
					end
				1: begin
					state <= AUX;
					auxaddr <= armaddr[19:0];
					auxwdata <= armwdata[{armaddr[1:0], 3'd0} +: 8];
					auxwr <= armwr;
					auxreq <= 1;
				end
				2:
					if(!armwr) begin
						state <= DEBUG;
						debugaddr <= armaddr[15:0];
						debugreq <= 1;
					end
				endcase
		AUX:
			if(auxack) begin
				state <= IDLE;
				auxreq <= 0;
				armack <= 1;
				armerr <= auxerr;
				armrdata <= {auxrdata, auxrdata, auxrdata, auxrdata};
			end
		DEBUG:
			if(debugack) begin
				state <= IDLE;
				debugreq <= 0;
				armack <= 1;
				armrdata <= debugrdata;
				armerr <= 0;
			end
		endcase
	end
endmodule
