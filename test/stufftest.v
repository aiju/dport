`include "dport.vh"

module stufftest(
);

	reg clk, reset, fifoempty;
	reg [47:0] fifodo;
	wire fiforden;
	reg dphstart, dpvstart;
	wire [15:0] dpdat0, dpdat1;
	wire [1:0] dpisk0, dpisk1;

	wire [15:0] vact = 40;
	wire [15:0] hact = 40;
	wire [15:0] vtot = 0;
	wire [15:0] htot = 0;
	wire [15:0] vsync = 0;
	wire [15:0] hsync = 0;
	wire [15:0] vdata = 0;
	wire [15:0] hdata = 0;
	wire [15:0] misc = 0;
	wire [23:0] Mvid = 0;
	wire [23:0] Nvid = 0;
	wire [15:0] sclkinc = 16'h5678;
	wire [`ATTRMAX:0] attr = {1'b0, sclkinc, Nvid, Mvid, misc, hdata, vdata, hsync, vsync, htot, vtot, hact, vact};
	
	initial begin
		clk = 1;
		reset = 1;
		fifoempty = 0;
		fifodo = 0;
		dphstart = 0;
		dpvstart = 0;
		fifodo = 48'h000001000000;
		
		#2 reset = 0;
		#4 dpvstart = 1;
		#1 dpvstart = 0;
	end
	
	always #0.5 clk = !clk;
	
	always @(posedge clk)
		if(fiforden)
			fifodo = fifodo + 48'h000002000002;

	stuff stuff0(clk, fifoempty, fifodo, fiforden, dphstart, dpvstart, 
		dpdat0, dpdat1, dpisk0, dpisk1,
		attr, reset);

endmodule
