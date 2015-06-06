`include "dport.vh"

module pxclk(
	input wire clk,
	input wire [`ATTRMAX:0] attr,
	input wire reset,
	output reg dphstart,
	output reg dpvstart,
	output reg dmastart
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
	wire [23:0] Mvid = attr[167:144];
	wire [23:0] Nvid = attr[191:168];
	wire [16:0] sclkinc = attr[208:192];

	reg [30:0] pxctr;
	reg [15:0] yctr;
	always @(posedge clk) begin
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


endmodule
