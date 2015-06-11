`include "dport.vh"

module cursor(
	input wire clk,
	input wire clkdmastart,
	input wire [47:0] dmado,
	input wire dmavalid,
	output reg [47:0] fifodi,
	output reg fifowren,
	
	input wire [31:0] curreg,
	
	input wire [5:0] curaddr,
	input wire [31:0] curwdata,
	input wire curreq,
	input wire [3:0] curwstrb,
	
	input wire [`ATTRMAX:0] attr
);

	wire [15:0] vact = attr[15:0];
	wire [15:0] hact = attr[31:16];
	reg [15:0] picx, picy;
	
	reg [31:0] clr[0:7], set[0:7];
	
	wire [31:0] memmask = {{8{curwstrb[3]}},{8{curwstrb[2]}},{8{curwstrb[1]}},{8{curwstrb[0]}}};
	always @(posedge clk) begin
		if(curreq) begin
			if(curaddr[5])
				set[curaddr[4:2]] <= set[curaddr[4:2]] & ~memmask | curwdata & memmask;
			else
				clr[curaddr[4:2]] <= clr[curaddr[4:2]] & ~memmask | curwdata & memmask;
		end
	end
	
	reg [31:0] curreg0;
	wire [15:0] x = picx - curreg0[31:16];
	wire [15:0] y = picy - curreg0[15:0];
	wire [3:0] x0 = ~x[3:0];
	wire [3:0] x1 = x0 - 1;
	reg [15:0] clr0, set0;
	
	always @(posedge clk) begin
		if(clkdmastart) begin
			picx <= 0;
			picy <= 0;
			curreg0 <= curreg;
		end
		clr0 <= clr[y[3:1]][!y[0] * 16 +: 16];
		set0 <= set[y[3:1]][!y[0] * 16 +: 16];
		fifowren <= dmavalid;
		if(dmavalid) begin
			fifodi <= dmado;
			if(y < 16) begin
				if(x < 16) begin
					if(clr0[x0])
						fifodi[23:0] <= -1;
					if(set0[x0])
						fifodi[23:0] <= 0;
				end
				if((x+1 & 'hffff) < 16) begin
					if(clr0[x1])
						fifodi[47:24] <= -1;
					if(set0[x1])
						fifodi[47:24] <= 0;
				end
			end
			picx <= picx + 2;
			if(picx + 2 == hact) begin
				picx <= 0;
				picy <= picy + 1;
			end
		end
	end
endmodule
