`include "dport.vh"

module pxclk(
	input wire clk,
	input wire dpclk,
	input wire [`ATTRMAX:0] attr,
	input wire speed,
	input wire reset,
	output reg dphstart,
	output reg dpvstart,
	output reg dmastart,
	output wire clkdmastart,
	output wire fiforeset
);

	wire [15:0] vact = attr[15:0];
	wire [15:0] hact = attr[31:16];
	wire [15:0] vtot = attr[47:32];
	wire [15:0] htot = attr[63:48];
	wire [15:0] vsync = attr[79:64];
	wire [15:0] hsync = attr[95:80];
	wire [15:0] vdata = attr[111:96];
	wire [15:0] hdata = attr[127:112];
	wire [15:0] misc = attr[143:128];
	wire [23:0] Mvid = speed ? attr[232:209] : attr[167:144];
	wire [23:0] Nvid = speed ? attr[256:233] : attr[191:168];
	wire [16:0] sclkinc = speed ? attr[273:257] : attr[208:192];

	reg [30:0] pxctr;
	reg [15:0] yctr;
	always @(posedge dpclk) begin
		dpvstart <= 0;
		dmastart <= 0;
		if(pxctr[30:15] >= htot) begin
			pxctr <= pxctr - {htot, 15'd0} + {15'd0, sclkinc};
			dphstart <= 1;
			if(yctr == vtot) begin
				dpvstart <= 1;
				yctr <= 0;
			end else
				yctr <= yctr + 1;
			if(yctr == vtot-1)
				dmastart <= 1;
		end else begin
			pxctr <= pxctr + {15'd0, sclkinc};
			dphstart <= 0;
		end
		if(reset) begin
			pxctr <= 0;
			yctr <= 0;
			dphstart <= 0;
			dpvstart <= 0;
			dmastart <= 0;
		end
	end
	
	reg start;
	initial start = 0;
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
	assign clkdmastart = start0 && !start00;
	always @(posedge clk)
		start00 <= start0;

endmodule
