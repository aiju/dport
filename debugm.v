`include "dport.vh"

module debugm(
	input wire clk,
	input wire dpclk,
	
	input wire start,
	input wire stop,
	
	input wire [15:0] debugaddr,
	input wire debugreq,
	output reg debugack,
	output reg [31:0] debugrdata,
	input wire debugwr,
	input wire [31:0] debugwdata
);

	parameter NSZ = 12;
	localparam SIZE = 1<<NSZ;

	reg mode;
	reg [31:0] mem[0:SIZE-1];
	reg [NSZ:0] addr;
	reg we;
	reg [31:0] rdata;
	reg [31:0] wdata;
	
	always @(*) begin
		if(mode) begin
			if(stop && running) begin
				addr = ctr;
				wdata = rdata + 1;
				we = 1;
			end else begin
				addr = ctr + 1;
				we = 0;
				wdata = 32'bx;
			end
		end else begin
			addr = debugaddr[NSZ+1:2];
			wdata = debugwdata;
			we = debugwr && debugreq0 && !debugreq00;
		end
	end
	
	always @(posedge clk)
		if(we)
			mem[addr] <= wdata;
		else
			rdata <= mem[addr];

	reg [NSZ:0] ctr;
	reg running;
	
	always @(posedge clk) begin
		if(start && mode) begin
			ctr <= 0;
			running <= 1;
		end else
			ctr <= ctr + 1;
		if(stop && running)
			running <= 0;
	end
	
	reg debugreq0, debugreq00;
	always @(posedge clk) begin
		debugreq0 <= debugreq;
		debugreq00 <= debugreq0;
		debugack <= 0;
		if(debugreq0 && !debugreq00) begin
			if(debugwr) begin
				if(debugaddr[15])
					mode <= debugwdata[0];
			end else
				debugrdata <= rdata;
			debugack <= 1;
		end
	end

endmodule
