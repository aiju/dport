`include "dport.vh"

module dmatest;

	reg clk;
	reg reset;
	
	wire dpclk = clk;
	reg dmastart;
	wire clkdmastart;
	
	wire [47:0] dmado;
	wire dmavalid;
	reg fifoalfull;
	wire fiforeset;
	
	reg [31:0] addrstart;
	reg [31:0] addrend;
	
	wire [31:0] araddr;
	wire [5:0] arid;
	wire [3:0] arlen;
	wire [2:0] arsize;
	wire [1:0] arburst;
	reg arready;
	wire arvalid;
	reg [63:0] rdata;
	reg [5:0] rid;
	reg rlast;
	wire rready;
	reg [1:0] rresp;
	reg rvalid;
	
	initial clk = 0;
	always #5 clk = !clk;

	initial begin
		$dumpfile("test.vcd");
		$dumpvars(0, dma0);
	
		reset <= 0;
		dmastart <= 0;
		fifoalfull <= 0;
		
		addrstart <= 'h1000_0000;
		addrend <= 'h1001_0000;
		
		arready <= 1;
		rvalid <= 0;
		rlast <= 0;
		
		@(posedge clk) dmastart <= 1;
		@(posedge clk) dmastart <= 0;
		#200 begin
			rdata <= 1;
			rvalid <= 1;
			rid <= 0;
		end
		repeat(15) #10 rdata <= rdata + 1;
		#10 rlast <= 1;
		#10 begin
			rvalid <= 0;
			rlast <= 0;
		end
		
		#40 begin
			rvalid <= 1;
			rid <= 1;
		end
		#150 rlast <= 1;
		#10 begin
			rvalid <= 0;
			rlast <= 0;
		end
	end
	
	initial #1000 $finish;

	dma dma0(clk, reset, dpclk, dmastart, clkdmastart, dmado, dmavalid, fifoalfull, fiforeset, addrstart, addrend, araddr, arid, arlen, arsize, arburst, arready, arvalid, rdata, rid, rlast, rready, rresp, rvalid);

endmodule
