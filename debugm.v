`include "dport.vh"

module debugm(
	input wire clk,
	input wire dpclk,
	
	input wire [15:0] txdat0,
	input wire [15:0] txdat1,
	input wire [1:0] txisk0,
	input wire [1:0] txisk1,
	
	input wire [15:0] debugaddr,
	input wire debugreq,
	output reg debugack,
	output reg [31:0] debugrdata
);

	parameter NSZ = 12;
	localparam SIZE = 1<<NSZ;

	reg [31:0] mem[0:SIZE-1];
	reg [3:0] isk[0:SIZE-1];
	
	wire trigger;
	
	assign trigger = txdat0[15:8] == `symBE && txisk0[1];
	reg [NSZ:0] ctr;
	
	always @(posedge dpclk) begin
		if(trigger && ctr[NSZ])
			ctr <= 0;
		if(!ctr[NSZ]) begin
			mem[ctr] <= {txdat1, txdat0};
			isk[ctr] <= {txisk1, txisk0};
			ctr <= ctr + 1;
		end
	end
	
	reg debugreq0, debugreq00;
	reg [31:0] datw;
	reg [3:0] iskw;
	always @(posedge clk) begin
		debugreq0 <= debugreq;
		debugreq00 <= debugreq0;
		debugack <= 0;
		datw <= mem[debugaddr[NSZ+1:2]];
		iskw <= isk[debugaddr[NSZ-1:0]];
		if(debugreq0 && !debugreq00) begin
			if(debugaddr[15])
				debugrdata <= {4{{4'b0, iskw}}};
			else
				debugrdata <= datw;
			debugack <= 1;
		end
	end

endmodule
