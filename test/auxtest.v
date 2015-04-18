`include "dport.vh"

module auxtest(
);

	reg clk;
	
	reg [19:0] auxaddr;
	reg [7:0] auxwdata;
	reg auxreq;
	reg auxwr;
	wire auxack;
	wire auxerr;
	wire [7:0] auxrdata;
	
	reg auxi;
	wire auxo;
	wire auxd;
	
	wire debug;
	wire debug2;
	
	aux aux0(clk, auxaddr, auxwdata, auxreq, auxwr, auxack, auxerr, auxrdata, auxi, auxo, auxd, debug, debug2);
	
	initial clk = 1;
	always #5 clk = !clk;
	reg [7:0] sr;
	
	initial begin
		auxaddr = 0;
		auxwdata = 0;
		auxreq = 0;
		auxwr = 0;
		auxi = 0;
		sr = 'hF0;
		
		#1000 auxreq = 1;
		#70000 repeat(41)
			#500 auxi = !auxi;
		#2000 auxi = !auxi;
		#2000 repeat(8) begin
			auxi = sr[7];
			#500 auxi = !auxi;
			#500 sr = {sr[6:0], 1'b0};
		end
		auxi = 1;
		#2000 auxi = !auxi;
	end
	
	always @(posedge clk)
		if(auxack) begin
			auxreq <= 0;
			#20 auxreq <= 1;
		end

endmodule
