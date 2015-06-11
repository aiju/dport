`include "dport.vh"

module dma(
	input wire clk,
	input wire reset,

	input wire clkdmastart,
	
	output reg [47:0] dmado,
	output reg dmavalid,
	input wire fifoalfull,
	
	input wire [31:0] addrstart,
	input wire [31:0] addrend,
	
	output reg [31:0] araddr,
	output reg [5:0] arid,
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
	input wire rvalid,
	
	input wire mode16
);

	parameter burst = 16;
	parameter par = 2;
	
	assign rready = 1;
	assign arlen = burst - 1;
	assign arsize = 3;
	assign arburst = 1;
	
	reg [63:0] mem[0:16 * par-1];
	reg [31:0] bufaddr[0:par-1];
	reg [4:0] wrpos[0:par-1];

	reg [par-1:0] issued;
	reg [3:0] pos, cur;
	reg [3:0] pos_, cur_;
	reg [31:0] outaddr, outaddr_;
	reg lastout;
	reg rdact, rdact_;
	reg half;
	integer i;
	
	always @(posedge clk) begin
		pos <= pos_;
		cur <= cur_;
		rdact <= rdact_;
		outaddr <= outaddr_;
		if(dmavalid)
			half <= !half;
		if(clkdmastart)
			half <= 0;
	end
	
	wire [63:0] bufpos = mem[{cur, pos}];
	wire [31:0] bufhalf = half ? bufpos[63:32] : bufpos[31:0];
	always @(*)
		if(mode16) begin
			dmado[23:16] = {bufhalf[4:0], {3{bufhalf[0]}}};
			dmado[15:8] = {bufhalf[10:5], {2{bufhalf[5]}}};
			dmado[7:0] = {bufhalf[15:11], {3{bufhalf[11]}}};
			dmado[47:40] = {bufhalf[20:16], {3{bufhalf[16]}}};
			dmado[39:32] = {bufhalf[26:21], {2{bufhalf[21]}}};
			dmado[31:24] = {bufhalf[31:27], {3{bufhalf[27]}}};
		end else
			dmado = {bufpos[55:32], bufpos[23:0]};			
			
	always @(*) begin
		pos_ = pos;
		cur_ = cur;
		rdact_ = rdact;
		outaddr_ = outaddr;
		lastout = 0;
		dmavalid = 0;
		if(rdact && !fifoalfull && pos < wrpos[cur]) begin
			if(!mode16 || half) begin
				pos_ = pos + 1;
				lastout = pos == burst - 1;
				if(lastout)
					pos_ = 0;
				outaddr_ = outaddr + 8;
			end
			dmavalid = 1;
		end
		if(lastout || !rdact) begin
			for(i = 0; i < par; i = i + 1)
				if(bufaddr[i] == outaddr_) begin
					cur_ = i;
					rdact_ = 1;
				end
		end
		if(clkdmastart) begin
			pos_ = 0;
			rdact_ = 0;
			outaddr_ = addrstart;
		end
	end
	
	reg [3:0] iidx;
	reg [31:0] inaddr;
	wire [3:0] widx = rid[3:0];
	reg [3:0] idx;
	reg running, arvalid_;
	
	always @(issued[0], issued[1]) begin
		arvalid_ = 0;
		if(running)
			for(i = 0; i < par; i = i + 1)
				if(!arvalid_ && !issued[i]) begin
					iidx = i;
					arvalid_ = 1;
				end
	end
	
	always @(posedge clk) begin
		araddr <= inaddr;
		arvalid <= arvalid_;
		arid <= iidx;
		if(arready && arvalid_) begin
			bufaddr[iidx] <= inaddr;
			issued[iidx] <= 1;
			inaddr <= inaddr + burst * 8;
			if(inaddr + burst * 8 >= addrend)
				running <= 0;
		end
	
		if(rvalid) begin
			mem[{widx, wrpos[widx][3:0]}] <= rdata;
			wrpos[widx] <= wrpos[widx] + 1;
		end
		
		if(lastout) begin
			issued[cur] <= 0;
			wrpos[cur] <= 0;
		end
		
		if(clkdmastart) begin
			for(i = 0; i < par; i = i + 1) begin
				issued[i] <= 0;
				wrpos[i] <= 0;
			end
			inaddr <= addrstart;
			running <= 1;
		end
	end

endmodule
