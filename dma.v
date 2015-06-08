`include "dport.vh"

module dma(
	input wire clk,
	input wire reset,
	
	input wire dpclk,
	input wire dmastart,
	output wire clkdmastart,
	
	output wire [47:0] dmado,
	output wire dmavalid,
	input wire fifoalfull,
	output wire fiforeset,
	
	input wire [31:0] addrstart,
	input wire [31:0] addrend,
	
	output reg [31:0] araddr,
	output wire [5:0] arid,
	output wire [3:0] arlen,
	output wire [2:0] arsize,
	output wire [1:0] arburst,
	input wire arready,
	output reg arvalid,
	input wire [63:0] rdata,
	input wire [5:0] rid,
	input wire rlast,
	output wire rready,
	input wire [1:0] rresp,
	input wire rvalid
);

	parameter burst = 16;
	
	reg start;
	wire start0, start1;
	reg start00;
	sync syncstart(clk, start, start0);
	sync syncstart0(dpclk, start0, start1);
	reg [2:0] ctr;
	assign fiforeset = ctr != 7;
	always @(posedge dpclk) begin
		if(dmastart)
			ctr <= 0;
		if(ctr != 7)
			ctr <= ctr + 1;
		if(ctr == 6)
			start <= 1;
		if(start1)
			start <= 0;
	end
			

	assign rready = 1;
	assign arlen = burst - 1;
	assign arsize = 3;
	assign arburst = 1;
	assign arid = 0;
	assign dmado = {rdata[55:32], rdata[23:0]};
	assign dmavalid = rvalid;
	reg issue;

	assign clkdmastart = start0 && !start00;
	always @(posedge clk) begin
		start00 <= start0;
		if(arvalid && arready)
			arvalid <= 0;
		if(rvalid) begin
			araddr <= araddr + 8;
			if(rlast)
				issue <= 1;
		end
		if(clkdmastart && !reset) begin
			araddr <= addrstart;
			issue <= 1;
		end
		if(!fifoalfull && issue) begin
			if(araddr < addrend && !reset)
				arvalid <= 1;
			issue <= 0;
		end
	end

endmodule
