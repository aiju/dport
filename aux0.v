`include "dport.vh"

module aux(
	input wire clk,
	
	input wire [19:0] auxaddr,
	input wire [7:0] auxwdata,
	input wire auxreq,
	input wire auxwr,
	output reg auxack,
	output reg auxerr,
	output reg [7:0] auxrdata,
	
	input wire auxi,
	output reg auxo,
	output reg auxd,
	
	output wire debug,
	output wire debug2
);
	
	localparam CLKDIV = 100;
	reg [6:0] auxdiv;
	wire auxclk = auxdiv < CLKDIV/2;
	wire auxtick = auxdiv == CLKDIV-1;
	initial auxdiv = 0;
	always @(posedge clk)
		if(auxtick)
			auxdiv <= 0;
		else
			auxdiv <= auxdiv + 1;

	parameter NCO = 20;
	parameter SYSMHZ = 100;
	parameter MAXKHZ = 1500;
	parameter MINKHZ = 750;
	localparam [NCO-1:0] MAXFREQ = 4.0 * MAXKHZ * (1<<NCO) / (SYSMHZ * 1000);
	localparam [NCO-1:0] MINFREQ = 4.0 * MINKHZ * (1<<NCO) / (SYSMHZ * 1000);
	reg [NCO-1:0] rxdiv, rxdiv_, fctr, fctr_, freq, alpha, beta;
	reg carry, rxclk, rxclkup, rxclkdn, rxa, rxb;

	initial begin
		rxdiv = 0;
		rxdiv_ = 0;
		fctr = (MAXKHZ+MINKHZ)/2;
		fctr_ = (MAXKHZ+MINKHZ)/2;
		rxclk = 0;
		rxa = 0;
		rxb = 0;
		alpha = 2500;
		beta = 50;
	end
	always @(posedge clk) begin
		if(rxclkdn)
			rxa <= rxb;
		if(rxclkup)
			rxb <= auxi;
	end
	wire up = auxi ^ rxb;
	wire down = rxa ^ rxb;
	always @(posedge clk) begin
		fctr <= fctr_;
		rxdiv <= rxdiv_;
	end
	always @(*) begin
		case({up,down})
		default: begin
			fctr_ = fctr;
			freq = fctr;
		end
		2'b10: begin
			freq = fctr + alpha;
			fctr_ = fctr + beta;
			if(fctr_ > MAXFREQ) fctr_ = MAXFREQ;
		end
		2'b01: begin
			freq = fctr - alpha;
			fctr_ = fctr - beta;
			if(fctr_ < MINFREQ) fctr_ = MINFREQ;
		end
		endcase
		{carry, rxdiv_} = {1'b0, rxdiv} + {1'b0, freq};
	end
	always @(posedge clk) begin
		rxclkup <= 0;
		rxclkdn <= 0;
		if(carry) begin
			rxclk <= !rxclk;
			if(rxclk)
				rxclkdn <= 1;
			else
				rxclkup <= 1;
		end
	end
	reg [7:0] rxd;
	reg rxdok;
	wire sync = rxd == 8'b11110000;
	always @(posedge clk) begin
		rxdok <= 0;
		if(rxclkup) begin
			rxd <= {rxd[6:0], auxi};
			rxdok <= 1;
		end
	end

	reg [2:0] txstate, txstate_, rxstate;
	reg rxstart, clrctr, incctr, clridx, incidx, loadsr, auxreq0;
	reg [3:0] ctr, idx;
	reg [7:0] sr;
	
	localparam IDLE = 0;
	localparam TXPREC = 1;
	localparam TXSYNC = 2;
	localparam TXDATA = 3;
	localparam TXEND = 4;
	localparam TXWAIT = 5;
	initial txstate = IDLE;
	initial auxreq0 = 0;
	always @(posedge clk) begin
		if(auxtick) begin
			txstate <= txstate_;
			if(txstate == IDLE && auxreq && !auxreq0)
				auxreq0 <= 1;
			ctr <= clrctr ? 0 : ctr + 1;
			if(clridx)
				idx <= 0;
			if(incidx)
				idx <= idx + 1;
			sr <= {sr[6:0], 1'b0};
			if(loadsr)
				case(incidx ? idx + 1 : idx)
				0: sr <= {3'b100, !auxwr, auxaddr[19:16]};
				1: sr <= auxaddr[15:8];
				2: sr <= auxaddr[7:0];
				3: sr <= 0;
				4: sr <= auxwdata;
				endcase
		end
		if(auxack)
			auxreq0 <= 0;
	end

	always @(*) begin
		txstate_ = txstate;
		clrctr = 0;
		clridx = 0;
		incidx = 0;
		loadsr = 0;
		auxo = 0;
		auxd = 1;
		rxstart = 0;
		case(txstate)
		IDLE:
			if(auxreq && !auxreq0) begin
				txstate_ = TXPREC;
				clrctr = 1;
				clridx = 1;
			end
		TXPREC: begin
			auxo = !auxclk;
			auxd = 0;
			if(ctr == 15) begin
				txstate_ = TXSYNC;
				clrctr = 1;
			end
		end
		TXSYNC: begin
			auxo = !ctr[1];
			auxd = 0;
			if(ctr == 3) begin
				txstate_ = TXDATA;
				clrctr = 1;
				loadsr = 1;
			end
		end
		TXDATA: begin
			auxo = !(auxclk ^ sr[7]);
			auxd = 0;
			if(ctr == 7) begin
				loadsr = 1;
				incidx = 1;
				clrctr = 1;
				if(idx == (auxwr ? 4 : 3))
					txstate_ = TXEND;
			end
		end
		TXEND: begin
			auxo = !ctr[1];
			auxd = 0;
			if(ctr == 3) begin
				clrctr = 1;
				txstate_ = TXWAIT;
				rxstart = 1;
			end
		end
		TXWAIT:
			if(rxstate == IDLE)
				txstate_ = IDLE;
		endcase
	end
	
	reg [3:0] inv, rxctr, rxbctr;
	initial rxstate = IDLE;
	reg [7:0] rxsr;
	reg rxbyte;
	localparam RXDELAY = 1;
	localparam RXWAIT = 2;
	localparam RXDATA = 3;
	localparam RXPARK = 4;
	
	always @(posedge clk) begin
		auxack <= 0;
		rxbyte <= 0;
		if(rxdok)
			rxctr <= sync ? 0 : rxctr + 1;
		case(rxstate)
		IDLE:
			if(rxstart) begin
				rxstate <= RXDELAY;
				rxbctr <= 0;
			end
		RXDELAY:
			if(rxdok) begin
				rxbctr <= rxbctr + 1;
				if(rxbctr == 7)
					rxstate <= RXWAIT;
			end
		RXWAIT:
			if(rxdok && sync) begin
				rxstate <= RXDATA;
				inv <= 0;
				rxbctr <= 0;
			end
		RXDATA:
			if(rxdok) begin
				if(rxctr[0]) begin
					rxsr <= {rxsr[6:0], rxd[1]};
					if(rxd[0] == rxd[1])
						inv <= inv + 1;
				end
				if(rxctr == 15)
					rxbyte <= 1;
				if(sync) begin
					rxstate <= RXPARK;
					auxack <= 1;
				end
			end
		RXPARK:
			if(rxdok && rxctr == 15)
				rxstate <= IDLE;
		endcase
		if(rxbyte) begin
			rxbctr <= rxbctr + 1;
			case(rxbctr)
			1: auxrdata <= rxsr;
			endcase
		end
	end

	reg [1:0] rxd0;
	always @(posedge clk) rxd0 <= rxd;
	assign debug = auxi;
	assign debug2 = rxd0[rxctr[0]];

endmodule
