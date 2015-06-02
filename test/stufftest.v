`include "dport.vh"

module stufftest(
);

	reg clk, reset, fifoempty;
	reg [47:0] fifodo;
	wire fiforden;
	wire dphstart, dpvstart;
	wire [15:0] dpdat0, dpdat1;
	wire [1:0] dpisk0, dpisk1;

	wire [15:0] vact = 480;
	wire [15:0] hact = 640;
	wire [15:0] vtot = 525;
	wire [15:0] htot = 800;
	wire [15:0] vsync = 2;
	wire [15:0] hsync = 96;
	wire [15:0] vdata = 35;
	wire [15:0] hdata = 144;
	wire [15:0] misc = 0;
	wire [23:0] Mvid = 162;
	wire [23:0] Nvid = 25;
	wire [15:0] sclkinc = 16'h5678;
	wire [`ATTRMAX:0] attr = {1'b0, sclkinc, Nvid, Mvid, misc, hdata, vdata, hsync, vsync, htot, vtot, hact, vact};
	integer i;
	
	initial begin
		clk = 1;
		reset = 1;
		fifoempty = 0;
		fifodo = 0;
		fifodo = 48'h000001000000;
		
		#2 reset = 0;
	end
	
	always #0.5 clk = !clk;
	
	always @(posedge clk)
		if(fiforden)
			fifodo = fifodo + 48'h000002000002;
	
	initial i = 0;
	task hexwrite;
	input [7:0] dat;
	input isk;
	begin
		if(isk)
			case(dat)
			`symBS: $write("BS ");
			`symBE: $write("BE ");
			`symSS: $write("SS ");
			`symSE: $write("SE ");
			`symFS: $write("FS ");
			`symFE: $write("FE ");
			`symSR: $write("SR ");
			endcase
		else
			$write("%2h ", dat);
		if(i == 31) begin
			$write("\n");
			i = 0;
		end else
			i = i + 1;
	end
	endtask
	
	always @(posedge clk) begin
		hexwrite(dpdat0[7:0], dpisk0[0]);
		hexwrite(dpdat0[15:8], dpisk0[1]);
	end

	stuff stuff0(clk, fifoempty, fifodo, fiforden, dphstart, dpvstart, 
		dpdat0, dpdat1, dpisk0, dpisk1,
		attr, reset);
	pxclk pxclk0(clk, attr, reset, dphstart, dpvstart);

endmodule
