`include "dport.vh"

module cursortest;

	reg clk;
	reg clkdmastart;
	reg [47:0] dmado;
	reg dmavalid;
	wire [47:0] fifodi;
	wire fifowren;
	
	reg [31:0] curreg;
	
	reg [5:0] curaddr;
	reg [31:0] curwdata;
	reg curreq;
	reg [3:0] curwstrb;
	
	wire [`ATTRMAX:0] attr;
	
	initial begin
		$dumpfile("test.vcd");
		$dumpvars(0, cursortest);
		
		clk = 0;
		clkdmastart = 0;
		dmado = {32'd1, 32'd0};
		dmavalid = 0;
		curreg = {16'h20, 16'd0};
		curaddr = 0;
		curwdata = 'h00010000;
		curreq = 1;
		curwstrb = -1;
		#10 curreq = 0;
		
		#10 clkdmastart = 1;
		#10 clkdmastart = 0;
		#10 dmavalid = 1;
		repeat(640) #10 dmado = dmado + {32'd2, 32'd2};
	end
	always #5 clk = !clk;
	initial #1000 $finish;

	assign attr[15:0] = 480; // vact
	assign attr[31:16] = 640; // hact
	
	cursor cursor0(clk, clkdmastart, dmado, dmavalid, fifodi, fifowren, curreg, curaddr, curwdata, curreq, curwstrb, attr);
	
endmodule
