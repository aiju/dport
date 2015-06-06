`include "dport.vh"

module top(
	input wire dpclk,
	input wire reset,
	input wire twolane,
	output wire [15:0] txdat0,
	output wire [15:0] txdat1,
	output wire [1:0] txisk0,
	output wire [1:0] txisk1
);
	wire dpclk, fifoempty, fiforden, dphstart, dpvstart, reset, gtpready;
	wire [1:0] dpisk0, dpisk1, scrisk0, scrisk1;
	wire [2:0] phymode;
	wire [15:0] dpdat0, dpdat1, scrdat0, scrdat1;
	reg [47:0] fifodo;
	reg [31:0] prng;
	wire [`ATTRMAX:0] attr;
	wire dmastart;
	
	always @(posedge dpclk) begin
		if(dmastart) begin
			prng = 0;
			fifodo <= 0;
		end else if(fiforden) begin
			fifodo[23:0] <= prng[23:0];
			prng = 1664525 * prng + 1013904223;
			fifodo[47:24] <= prng[23:0];
			prng = 1664525 * prng + 1013904223;
		end
	end
	
	assign attr[15:0] = 480; // vact
	assign attr[31:16] = 640; // hact
	assign attr[47:32] = 525; // vtot
	assign attr[63:48] = 800; // htot
	assign attr[79:64] = 'h8002; // vsync
	assign attr[95:80] = 'h8060; // hsync
	assign attr[111:96] = 35; // vdata
	assign attr[127:112] = 144; // hdata
	assign attr[143:128] = 'h21; // misc
	assign attr[167:144] = 42; // Mvid
	assign attr[191:168] = 275; // Nvid
	assign attr[207:192] = 'h2719; // sclkinc
	assign attr[208] = twolane;
	assign phymode = 1;
	

	pxclk pxclk0(dpclk, attr, reset, dphstart, dpvstart, dmastart);
	stuff stuff0(dpclk, fifoempty, 0, fifodo, fiforden, dphstart, dpvstart, dmastart, dpdat0, dpdat1, dpisk0, dpisk1, attr, reset);
	scrambler scr0(dpclk, dpdat0, dpisk0, scrdat0, scrisk0);
	scrambler scr1(dpclk, dpdat1, dpisk1, scrdat1, scrisk1);
	phy phy0(dpclk, phymode, scrdat0, scrdat1, scrisk0, scrisk1, txdat0, txdat1, txisk0, txisk1);

endmodule
