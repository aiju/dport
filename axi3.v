`include "dport.vh"

module axi3(
	clk,
	resetn,
	arvalid,
	awvalid,
	bready,
	rready,
	wlast,
	wvalid,
	arid,
	awid,
	wid,
	arburst,
	arlock,
	arsize,
	awburst,
	awlock,
	awsize,
	arprot,
	awprot,
	araddr,
	awaddr,
	wdata,
	arcache,
	arlen,
	arqos,
	awcache,
	awlen,
	awqos,
	wstrb,
	arready,
	awready,
	bvalid,
	rlast,
	rvalid,
	wready,
	bid,
	rid,
	bresp,
	rresp,
	rdata,
	
	outaddr,
	outrdata,
	outwdata,
	outwr,
	outreq,
	outack,
	outwstrb,
	outerr
);

	parameter ADDR = 32;
	parameter DATA = 32;
	parameter ID = 12;
	parameter TIMEBITS = 20;
	parameter TIMEOUT = 1048575;
	
	input wire clk, resetn;
	
	input wire awvalid;
	output reg awready;
	input wire [1:0] awburst, awlock;
	input wire [2:0] awsize, awprot;
	input wire [3:0] awlen, awcache, awqos;
	input wire [ID-1:0] awid;
	input wire [ADDR-1:0] awaddr;
	
	input wire arvalid;
	output reg arready;
	input wire [1:0] arburst, arlock;
	input wire [2:0] arsize, arprot;
	input wire [3:0] arlen, arcache, arqos;
	input wire [ID-1:0] arid;
	input wire [ADDR-1:0] araddr;
	
	input wire wvalid, wlast;
	output reg wready;
	input wire [DATA/8-1:0] wstrb;
	input wire [ID-1:0] wid;
	input wire [DATA-1:0] wdata;

	output reg bvalid;
	input wire bready;
	output reg [1:0] bresp;
	output reg [ID-1:0] bid;
	
	output reg rvalid;
	input wire rready;
	output reg [1:0] rresp;
	output reg rlast;
	output reg [ID-1:0] rid;
	output reg [DATA-1:0] rdata;
	
	output reg [ADDR-1:0] outaddr;
	input wire [DATA-1:0] outrdata;
	output reg [DATA-1:0] outwdata;
	output reg outwr;
	output reg outreq;
	input wire outack;
	input wire outerr;
	output reg [DATA/8-1:0] outwstrb;
	
	localparam OKAY = 0;
	localparam EXOKAY = 1;
	localparam SLVERR = 2;
	localparam DECERR = 3;
	localparam FIXED = 0;
	localparam INCR = 1;
	localparam WRAP = 2;
	
	reg [1:0] awburst0;
	reg [2:0] awsize0;
	reg [ID-1:0] awid0;
	reg [ADDR-1:0] awaddr0;
	
	reg [1:0] arburst0;
	reg [2:0] arsize0;
	reg [3:0] arlen0;
	reg [ADDR-1:0] araddr0;
	
	reg outerr0;
	reg [ADDR-1:0] curaddr, nextaddr;
	reg [1:0] burst, bresp_;
	reg [2:0] size;
	reg [7:0] sizedec;
	reg [TIMEBITS-1:0] timer;
	reg timeout, timeout0;
	
	reg [2:0] state, state_;
	localparam IDLE = 0;
	localparam READOUT = 1;
	localparam READREPLY = 2;
	localparam WAITWRDATA = 3;
	localparam WRITEOUT = 4;
	localparam WRRESP = 5;
	
	reg setoutaddrr, setoutaddrw, latchrdata, latchwdata, latchar, latchaw, incraddr, incwaddr, starttime;
	reg rpend, rpend_, write;
	
	always @(posedge clk, negedge resetn) begin
		state <= !resetn ? IDLE : state_;
		rpend <= !resetn ? 0 : rpend_;
	end
	
	always @(posedge clk) begin
		bresp <= bresp_;
		if(latchaw) begin
			awaddr0 <= awaddr;
			awburst0 <= awburst;
			awsize0 <= awsize;
			arlen0 <= arlen;
			bid <= awid;
		end
		if(latchar) begin
			araddr0 <= araddr;
			arburst0 <= arburst;
			arsize0 <= arsize;
			arlen0 <= arlen;
			rid <= arid;
		end
		if(incwaddr)
			awaddr0 <= nextaddr;
		if(incraddr) begin
			araddr0 <= nextaddr;
			arlen0 <= arlen0 - 1;
		end
		if(latchwdata) begin
			outwdata <= wdata;
			outwstrb <= wstrb;
		end
		if(latchrdata) begin
			rdata <= outrdata;
			outerr0 <= outerr;
			timeout0 <= timeout;
		end
		if(timer > 0)
			timer <= timer - 1;
		if(starttime)
			timer <= TIMEOUT;
	end
	
	always @(*) begin
		burst = write ? awburst0 : arburst0;
		size = write ? awsize0 : arsize0;
		sizedec = 0;
		sizedec[size] = 1;
		curaddr = write ? awaddr0 : araddr0;
		case(burst)
		default: nextaddr = curaddr;
		INCR: nextaddr = curaddr + sizedec;
		endcase
		
		timeout = TIMEOUT != 0 && timer == 0;
		
		outaddr = write ? awaddr0 : araddr0;
	end
	
	always @(*) begin
		state_ = state;
		write = 0;
		awready = 0;
		arready = 0;
		wready = 0;
		rvalid = 0;
		bvalid = 0;
		rlast = 0;
		rresp = 0;
		rpend_ = rpend;
		
		latchar = 0;
		latchaw = 0;
		latchrdata = 0;
		latchwdata = 0;
		incraddr = 0;
		incwaddr = 0;
		setoutaddrr = 0;
		setoutaddrw = 0;
		starttime = 0;
		bresp_ = bresp;
		
		outaddr = 'hx;
		outwdata = 'hx;
		outwr = 0;
		outreq = 0;
		case(state)
		IDLE: begin
			awready = 1;
			arready = 1;
			if(awvalid) begin
				if(arvalid) begin
					latchar = 1;
					rpend_ = 1;
				end
				state_ = WAITWRDATA;
				latchaw = 1;
				bresp_ = 0;
			end else if(arvalid) begin
				state_ = READOUT;
				starttime = 1;
				latchar = 1;
			end
		end
		READOUT: begin
			outreq = 1;
			if(outack || timeout) begin
				state_ = READREPLY;
				latchrdata = 1;
			end
		end
		READREPLY: begin
			rvalid = 1;
			rresp = timeout0 ? DECERR : outerr0 ? SLVERR : OKAY;
			rlast = arlen0 == 0;
			if(rready)
				if(rlast)
					state_ = IDLE;
				else begin
					state_ = READOUT;
					incraddr = 1;
					starttime = 1;
				end
		end
		WAITWRDATA: begin
			write = 1;
			wready = 1;
			if(wvalid) begin
				latchwdata = 1;
				if(wstrb == 0) begin
					if(wlast)
						state_ = WRRESP;
				end else begin
					state_ = WRITEOUT;
					starttime = 1;
				end
			end
		end
		WRITEOUT: begin
			write = 1;
			outwr = 1;
			outreq = 1;
			if(outack || timeout) begin
				if(timeout)
					bresp_ = DECERR;
				else if(outerr)
					bresp_ = SLVERR;
				state_ = wlast ? WRRESP : WAITWRDATA;
			end
		end
		WRRESP: begin
			write = 1;
			bvalid = 1;
			if(bready)
				if(rpend) begin
					rpend_ = 0;
					state_ = READOUT;
					starttime = 1;
				end else
					state_ = IDLE;
		end
		endcase
	end
	
endmodule
