`include "dport.vh"

module train(
	input wire clk,
	
	input wire [19:0] regauxaddr,
	input wire [7:0] regauxwdata,
	input wire regauxreq,
	input wire regauxwr,
	output reg regauxack,
	output reg regauxerr,
	output reg [7:0] regauxrdata,
	
	input wire [31:0] phyctl,
	output wire [31:0] physts,
	
	output reg [19:0] auxaddr,
	output reg [7:0] auxwdata,
	output reg auxreq,
	output reg auxwr,
	input wire auxack,
	input wire [7:0] auxrdata,
	input wire auxerr,
	
	output reg reset,
	output reg speed,
	output reg twolane,
	output reg [1:0] preemph,
	output reg [1:0] swing,
	output reg [1:0] phymode,
	output reg [2:0] prbssel
);

	localparam TRAINPERIOD = 1_000_000;
	localparam CHECKPERIOD = 25_000_000;
	localparam TRAINLIMIT = 5;
	localparam ACTLIMIT = 5;
	
	wire automode = phyctl[31];

	reg [1:0] muxstate, muxstate_;
	localparam MUXIDLE = 0;
	localparam MUXTR = 1;
	localparam MUXREG = 2;
	reg [19:0] traddr;
	reg [7:0] trwdata, trrdata, trrdata_, regauxrdata_;
	reg trreq, track, trerr, trwr, track_, trerr_, regauxack_, regauxerr_;
	always @(posedge clk) begin
		muxstate <= muxstate_;
		track <= track_;
		trerr <= trerr_;
		trrdata <= trrdata_;
		regauxack <= regauxack_;
		regauxerr <= regauxerr_;
		regauxrdata <= regauxrdata_;
	end
	always @(*) begin
		auxaddr = 20'bx;
		auxwdata = 8'bx;
		auxreq = 0;
		auxwr = 0;
		muxstate_ = muxstate;
		track_ = 0;
		trrdata_ = trrdata;
		trerr_ = trerr;
		regauxack_ = 0;
		regauxrdata_ = regauxrdata;
		regauxerr_ = regauxerr;
		case(muxstate)
		MUXIDLE: begin
			if(regauxreq)
				muxstate_ = MUXREG;
			else if(trreq)
				muxstate_ = MUXTR;
		end
		MUXTR: begin
			auxaddr = traddr;
			auxwdata = trwdata;
			auxreq = 1;
			auxwr = trwr;
			if(auxack) begin
				track_ = 1;
				trrdata_ = auxrdata;
				trerr_ = auxerr;
				muxstate_ = MUXIDLE;
			end
		end
		MUXREG: begin
			auxaddr = regauxaddr;
			auxwdata = regauxwdata;
			auxreq = 1;
			auxwr = regauxwr;
			if(auxack) begin
				regauxack_ = 1;
				regauxrdata_ = auxrdata;
				regauxerr_ = auxerr;
				muxstate_ = MUXIDLE;
			end
		end
		endcase
	end

	reg [3:0] state, state_;
	reg [3:0] actctr, actctr_;
	reg [31:0] timer, timer_;
	reg speed_, twolane_, reset_;
	reg [1:0] swing_, preemph_, phymode_;
	
	assign physts = {state != NOAUTO, 7'b0, actctr, state, 2'b0, reset, prbssel, phymode, swing, preemph, 2'b0, twolane, speed};
	
	localparam NODEV = 0;
	localparam CHECKNODEV = 1;
	localparam SETLINKBW = 2;
	localparam SETLANECNT = 3;
	localparam SETTRAIN0 = 4;
	localparam WAITTRAIN0 = 5;
	localparam CHECKTRAIN0 = 6;
	localparam SETTRAIN1 = 7;
	localparam WAITTRAIN1 = 8;
	localparam CHECKTRAIN1 = 9;
	localparam SETACTIVE = 10;
	localparam ACTIVE = 11;
	localparam CHECKACTIVE = 12;
	localparam CHANGESET = 13;
	localparam NOAUTO = 14;
	
	always @(posedge clk) begin
		state <= state_;
		speed <= speed_;
		twolane <= twolane_;
		preemph <= preemph_;
		swing <= swing_;
		phymode <= phymode_;
		timer <= timer_;
		actctr <= actctr_;
		reset <= reset_;
	end
	
	always @(*) begin
		traddr = 20'bx;
		trwdata = 8'bx;
		trreq = 0;
		trwr = 0;
		state_ = state;
		speed_ = speed;
		twolane_ = twolane;
		preemph_ = preemph;
		swing_ = swing;
		phymode_ = phymode;
		actctr_ = actctr;
		reset_ = 1;
		timer_ = timer != 0 ? timer - 1 : 0;
		prbssel = 0;
	
		case(state)
		NODEV: begin
			preemph_ = 0;
			swing_ = 0;
			speed_ = 1;
			twolane_ = 1;
			if(timer == 0)
				state_ = CHECKNODEV;
		end
		CHECKNODEV: begin
			traddr = 'h0;
			trreq = 1;
			if(track)
				if(trerr) begin
					state_ = NODEV;
					timer_ = CHECKPERIOD;
				end else
					state_ = SETLINKBW;
		end
		SETLINKBW: begin
			traddr = 'h100;
			trwdata = speed ? 10 : 6;
			trreq = 1;
			trwr = 1;
			if(track)
				state_ = trerr ? NODEV : SETLANECNT;
		end
		SETLANECNT: begin
			traddr = 'h101;
			trwdata = twolane ? 2 : 1;
			trreq = 1;
			trwr = 1;
			if(track)
				state_ = trerr ? NODEV : SETTRAIN0;
		end
		SETTRAIN0: begin
			traddr = 'h102;
			trwdata = 'h21;
			trreq = 1;
			trwr = 1;
			if(track)
				if(trerr)
					state_ = NODEV;
				else begin
					phymode_ = 2;
					timer_ = TRAINPERIOD;
					state_ = WAITTRAIN0;
					actctr_ = 0;
				end
		end
		WAITTRAIN0: begin
			if(timer == 0)
				state_ = CHECKTRAIN0;
		end
		CHECKTRAIN0: begin
			traddr = 'h202;
			trreq = 1;
			if(track) begin
				if(trerr)
					state_ = NODEV;
				else if(trrdata[0] && (!twolane || trrdata[4]))
					state_ = SETTRAIN1;
				else if(actctr == TRAINLIMIT)
					state_ = CHANGESET;
				else begin
					state_ = WAITTRAIN0;
					timer_ = TRAINPERIOD;
					actctr_ = actctr + 1;
				end
			end
		end
		SETTRAIN1: begin
			traddr = 'h102;
			trwdata = 'h22;
			trreq = 1;
			trwr = 1;
			if(track)
				if(trerr)
					state_ = NODEV;
				else begin
					phymode_ = 3;
					state_ = WAITTRAIN1;
					timer_ = TRAINPERIOD;
					actctr_ = 0;
				end
		end
		WAITTRAIN1: begin
			if(timer == 0)
				state_ = CHECKTRAIN1;
		end
		CHECKTRAIN1: begin
			traddr = 'h202;
			trreq = 1;
			if(track) begin
				if(trerr)
					state_ = NODEV;
				else if(trrdata[2:0] == 7 && (!twolane || trrdata[6:4] == 7))
					state_ = SETACTIVE;
				else if(actctr == TRAINLIMIT)
					state_ = CHANGESET;
				else begin
					state_ = WAITTRAIN0;
					timer_ = TRAINPERIOD;
					actctr_ = actctr + 1;
				end
			end
		end
		SETACTIVE: begin
			traddr = 'h102;
			trwdata = 0;
			trreq = 1;
			trwr = 1;
			if(track)
				if(trerr)
					state_ = NODEV;
				else begin
					state_ = ACTIVE;
					timer_ = CHECKPERIOD;
					phymode_ = 1;
					actctr_ = 0;
				end
		end
		ACTIVE: begin
			reset_ = 0;
			if(timer == 0)
				state_ = CHECKACTIVE;
		end
		CHECKACTIVE: begin
			reset_ = 0;
			traddr = 'h202;
			trreq = 1;
			if(track)
				if(trerr)
					state_ = NODEV;
				else if(trrdata[2:0] == 7 && (!twolane || trrdata[6:4] == 7)) begin
					timer_ = CHECKPERIOD;
					state_ = ACTIVE;
					actctr_ = actctr == ACTLIMIT ? actctr : actctr + 1;
				end else if(actctr == ACTLIMIT) begin
					phymode_ = 2;
					state_ = SETTRAIN0;
				end else		
					state_ = CHANGESET;
		end
		CHANGESET: begin
			preemph_ = preemph + 1;
			state_ = SETTRAIN0;
			if(swing + preemph == 3) begin
				preemph_ = 0;
				swing_ = swing + 1;
				if(preemph == 3) begin
					speed_ = !speed;
					if(!speed)
						twolane_ = !twolane;
					state_ = SETLINKBW;
				end
			end
		end
		NOAUTO: begin
			speed_ = phyctl[0];
			twolane_ = phyctl[1];
			preemph_ = phyctl[5:4];
			swing_ = phyctl[7:6];
			phymode_ = phyctl[9:8];
			prbssel = phyctl[12:10];
			reset_ = phyctl[13];
			if(automode)
				state_ = NODEV;
		end
		endcase
		if(!automode)
			state_ = NOAUTO;
	end

endmodule
