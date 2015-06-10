`include "dport.vh"

module top(
	input wire [1:0] refclk,
	output wire [3:0] tx,
	inout wire auxp,
	inout wire auxn,
	output wire debug,
	output wire debug2
);

	wire gp0_awvalid;
	wire gp0_awready;
	wire [1:0] gp0_awburst, gp0_awlock;
	wire [2:0] gp0_awsize, gp0_awprot;
	wire [3:0] gp0_awlen, gp0_awcache, gp0_awqos;
	wire [11:0] gp0_awid;
	wire [31:0] gp0_awaddr;

	wire gp0_arvalid;
	wire gp0_arready;
	wire [1:0] gp0_arburst, gp0_arlock;
	wire [2:0] gp0_arsize, gp0_arprot;
	wire [3:0] gp0_arlen, gp0_arcache, gp0_arqos;
	wire [11:0] gp0_arid;
	wire [31:0] gp0_araddr;

	wire gp0_wvalid, gp0_wlast;
	wire gp0_wready;
	wire [3:0] gp0_wstrb;
	wire [11:0] gp0_wid;
	wire [31:0] gp0_wdata;

	wire gp0_bvalid;
	wire gp0_bready;
	wire [1:0] gp0_bresp;
	wire [11:0] gp0_bid;

	wire gp0_rvalid;
	wire gp0_rready;
	wire [1:0] gp0_rresp;
	wire gp0_rlast;
	wire [11:0] gp0_rid;
	wire [31:0] gp0_rdata;
	
	wire hp0_arvalid;
	wire hp0_arready;
	wire [1:0] hp0_arburst;
	wire [2:0] hp0_arsize;
	wire [3:0] hp0_arlen;
	wire [11:0] hp0_arid;
	wire [31:0] hp0_araddr;

	wire hp0_rvalid;
	wire hp0_rready;
	wire [1:0] hp0_rresp;
	wire hp0_rlast;
	wire [11:0] hp0_rid;
	wire [63:0] hp0_rdata;

	wire [31:0] armaddr;
	wire [31:0] armrdata, armwdata;
	wire [3:0] armwstrb;
	wire armwr, armreq;
	wire armack, armerr;
	
	wire [19:0] auxaddr;
	wire [7:0] auxrdata, auxwdata;
	wire auxreq, auxack, auxwr, auxerr;
	wire [19:0] regauxaddr;
	wire [7:0] regauxrdata, regauxwdata;
	wire regauxreq, regauxack, regauxwr, regauxerr;
	wire auxi, auxo, auxd;
	wire [31:0] phyctl, physts;
	
	wire [15:0] debugaddr;
	wire [31:0] debugrdata, debugwdata;
	wire debugreq, debugack, debugwr;
	
	wire [5:0] curaddr;
	wire [31:0] curwdata;
	wire curreq;
	wire [3:0] curwstrb;
	
	wire dpclk, dmavalid, fifowren, fifoempty, fifoalfull, fiforden, dphstart, dpvstart, reset, gtpready;
	wire [1:0] dpisk0, dpisk1, scrisk0, scrisk1, txisk0, txisk1, phymode;
	wire [2:0] prbssel;
	wire [3:0] fclk, fresetn;
	wire [15:0] dpdat0, dpdat1, scrdat0, scrdat1, txdat0, txdat1;
	wire [47:0] dmado, fifodi, fifodo;
	wire [`ATTRMAX:0] attr;
	
	wire [31:0] addrstart, addrend, curreg;
	wire dmastart, clkdmastart;
	wire fiforeset;
	
	wire speed, twolane;
	wire [1:0] preemph, swing;
	
	wire clk = fclk[0];
	wire resetn = fresetn[0];

	axi3 axi3_0(
		clk, resetn,

		gp0_arvalid, gp0_awvalid, gp0_bready, gp0_rready, gp0_wlast, gp0_wvalid, gp0_arid, gp0_awid,
		gp0_wid, gp0_arburst, gp0_arlock, gp0_arsize, gp0_awburst, gp0_awlock, gp0_awsize, gp0_arprot,
		gp0_awprot, gp0_araddr, gp0_awaddr, gp0_wdata, gp0_arcache, gp0_arlen, gp0_arqos, gp0_awcache,
		gp0_awlen, gp0_awqos, gp0_wstrb, gp0_arready, gp0_awready, gp0_bvalid, gp0_rlast, gp0_rvalid,
		gp0_wready, gp0_bid, gp0_rid, gp0_bresp, gp0_rresp, gp0_rdata,

		armaddr, armrdata, armwdata, armwr, armreq, armack, armwstrb, armerr
	);

	regs regs0(clk, armaddr, armrdata, armwdata, armwr, armreq, armack, armwstrb, armerr,
		regauxaddr, regauxwdata, regauxreq, regauxwr, regauxack, regauxerr, regauxrdata,
		debugaddr, debugreq, debugack, debugrdata, debugwdata, debugwr,
		curaddr, curwdata, curreq, curwstrb,
		attr, addrstart, addrend, curreg, phyctl, physts
	);
	train train0(clk,
		regauxaddr, regauxwdata, regauxreq, regauxwr, regauxack, regauxerr, regauxrdata,
		phyctl, physts,
		auxaddr, auxwdata, auxreq, auxwr, auxack, auxrdata, auxerr,
		reset, speed, twolane, preemph, swing, phymode, prbssel
	);
	aux aux0(clk, auxaddr, auxwdata, auxreq, auxwr, auxack, auxerr, auxrdata, auxi, auxo, auxd);
	pxclk pxclk0(clk, dpclk, attr, speed, reset, dphstart, dpvstart, dmastart, clkdmastart, fiforeset);
	assign debug = armack | (|armrdata);
	assign debug2 = 0;
	
	dma dma0(clk, reset, clkdmastart,
		dmado, dmavalid, fifoalfull, addrstart, addrend,
		hp0_araddr, hp0_arid, hp0_arlen, hp0_arsize, hp0_arburst, hp0_arready, hp0_arvalid,
		hp0_rdata, hp0_rid, hp0_rlast, hp0_rready, hp0_rresp, hp0_rvalid
	);
	cursor cursor0(clk, clkdmastart, dmado, dmavalid, fifodi, fifowren,
		curreg, curaddr, curwdata, curreq, curwstrb,
		attr
	);
	FIFO36E1 #(
		.DATA_WIDTH("72"),
		.SIM_DEVICE("7SERIES"),
		.FIFO_MODE("FIFO36_72"),
		.ALMOST_FULL_OFFSET(32),
		.FIRST_WORD_FALL_THROUGH("TRUE")
	) fifo(
		.WRCLK(clk),
		.WREN(fifowren),
		.DI(fifodi),
		.ALMOSTFULL(fifoalfull),
		
		.RDCLK(dpclk),
		.DO(fifodo),
		.RDEN(fiforden && !fiforeset),
		.EMPTY(fifoempty),
		.RST(fiforeset)
	);
	stuff stuff0(dpclk, fifoempty, fiforeset, fifodo, fiforden, dphstart, dpvstart, dmastart, dpdat0, dpdat1, dpisk0, dpisk1, attr, twolane, speed, reset);
	scrambler scr0(dpclk, dpdat0, dpisk0, scrdat0, scrisk0);
	scrambler scr1(dpclk, dpdat1, dpisk1, scrdat1, scrisk1);
	phy phy0(dpclk, phymode, scrdat0, scrdat1, scrisk0, scrisk1, txdat0, txdat1, txisk0, txisk1);
	gtp gtp0(clk, refclk, dpclk, gtpready, prbssel, txdat0, txdat1, txisk0, txisk1, tx, speed, preemph, swing);
	debugm debugm0(clk, dpclk, hp0_arvalid && hp0_arready, hp0_rvalid, debugaddr, debugreq, debugack, debugrdata, debugwr, debugwdata);

	wire auxi0;
	sync auxsync(clk, !auxi0, auxi);
	PULLUP p0(.O(auxp));
	PULLDOWN p1(.O(auxn));
	IOBUFDS #(.DIFF_TERM("false"), .IOSTANDARD("BLVDS_25")) io_1(.I(!auxo), .O(auxi0), .T(auxd), .IO(auxp), .IOB(auxn));

	PS7 PS7_0(
		.MAXIGP0ARVALID(gp0_arvalid),
		.MAXIGP0AWVALID(gp0_awvalid),
		.MAXIGP0BREADY(gp0_bready),
		.MAXIGP0RREADY(gp0_rready),
		.MAXIGP0WLAST(gp0_wlast),
		.MAXIGP0WVALID(gp0_wvalid),
		.MAXIGP0ARID(gp0_arid),
		.MAXIGP0AWID(gp0_awid),
		.MAXIGP0WID(gp0_wid),
		.MAXIGP0ARBURST(gp0_arburst),
		.MAXIGP0ARLOCK(gp0_arlock),
		.MAXIGP0ARSIZE(gp0_arsize),
		.MAXIGP0AWBURST(gp0_awburst),
		.MAXIGP0AWLOCK(gp0_awlock),
		.MAXIGP0AWSIZE(gp0_awsize),
		.MAXIGP0ARPROT(gp0_arprot),
		.MAXIGP0AWPROT(gp0_awprot),
		.MAXIGP0ARADDR(gp0_araddr),
		.MAXIGP0AWADDR(gp0_awaddr),
		.MAXIGP0WDATA(gp0_wdata),
		.MAXIGP0ARCACHE(gp0_arcache),
		.MAXIGP0ARLEN(gp0_arlen),
		.MAXIGP0ARQOS(gp0_arqos),
		.MAXIGP0AWCACHE(gp0_awcache),
		.MAXIGP0AWLEN(gp0_awlen),
		.MAXIGP0AWQOS(gp0_awqos),
		.MAXIGP0WSTRB(gp0_wstrb),
		.MAXIGP0ACLK(clk),
		.MAXIGP0ARREADY(gp0_arready),
		.MAXIGP0AWREADY(gp0_awready),
		.MAXIGP0BVALID(gp0_bvalid),
		.MAXIGP0RLAST(gp0_rlast),
		.MAXIGP0RVALID(gp0_rvalid),
		.MAXIGP0WREADY(gp0_wready),
		.MAXIGP0BID(gp0_bid),
		.MAXIGP0RID(gp0_rid),
		.MAXIGP0BRESP(gp0_bresp),
		.MAXIGP0RRESP(gp0_rresp),
		.MAXIGP0RDATA(gp0_rdata),
	
		.SAXIHP0ACLK(clk),
		.SAXIHP0ARVALID(hp0_arvalid),
		.SAXIHP0ARREADY(hp0_arready),
		.SAXIHP0ARSIZE(hp0_arsize),
		.SAXIHP0ARLEN(hp0_arlen),
		.SAXIHP0ARBURST(hp0_arburst),
		.SAXIHP0ARID(hp0_arid),
		.SAXIHP0ARADDR(hp0_araddr),
		.SAXIHP0RVALID(hp0_rvalid),
		.SAXIHP0RREADY(hp0_rready),
		.SAXIHP0RID(hp0_rid),
		.SAXIHP0RDATA(hp0_rdata),
		.SAXIHP0RRESP(hp0_rresp),
		.SAXIHP0RLAST(hp0_rlast),
		.SAXIHP0ARQOS(15),

		.FCLKCLK(fclk),
		.FCLKRESETN(fresetn)
	);

endmodule
