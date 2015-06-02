`include "dport.vh"

module stuff(
	input wire dpclk,
	input wire fifoempty,
	input wire [47:0] fifodo,
	output reg fiforden,
	
	input wire dphstart,
	input wire dpvstart,
	
	output reg [15:0] dpdat0,
	output reg [15:0] dpdat1,
	output reg [1:0] dpisk0,
	output reg [1:0] dpisk1,
	
	input wire [`ATTRMAX:0] attr,
	input wire reset
);

	parameter MAXCTR = 15;

	reg [3:0] state, state_;
	localparam IDLE = 0;
	localparam ACTIVE = 1;
	localparam STUFF = 2;
	localparam VBLANK = 3;
	localparam VBID = 4;
	localparam EOL = 5;
	
	reg hstart, vstart, hstart_, vstart_, pxcons;

	wire [15:0] vact = attr[15:0];
	wire [15:0] hact = attr[31:16];
	wire [15:0] vtot = attr[47:32];
	wire [15:0] htot = attr[63:48];
	wire [15:0] vsync = attr[79:64];
	wire [15:0] hsync = attr[95:80];
	wire [15:0] vdata = attr[111:96];
	wire [15:0] hdata = attr[127:112];
	wire [15:0] misc = attr[143:128];
	wire [23:0] Mvid = attr[167:144];
	wire [23:0] Nvid = attr[191:168];
	wire [15:0] sclkinc = attr[207:192];
	wire twolane = attr[208];
	
	reg [23:0] px[0:3];
	reg [2:0] pxfill, pxfill_;
	reg [1:0] pxrem, pxrem_;
	reg [5:0] tuctr, ctr, tuctr_, ctr_;
	reg [15:0] xrem, xrem_, yrem, yrem_;
	
	reg [18:0] tufctr;
	wire [19:0] tufround = tufctr + 'h800;
	wire [5:0] tufill = tufround[16:11];
	wire [18:0] tufinc = ({3'd0, sclkinc} << 1) + {3'd0, sclkinc};
	wire [19:0] tufincround = tufinc + 'h800;
	reg tufreset, tufstep;
	
	always @(posedge dpclk) begin
		if(reset) begin
			state <= IDLE;
			hstart <= 0;
			vstart <= 0;
			pxrem <= 0;
			tuctr <= 0;
			pxfill <= 0;
			xrem <= 0;
			yrem <= 0;
			ctr <= 0;
			tufctr <= 0;
		end else begin
			state <= state_;
			hstart <= hstart_;
			vstart <= vstart_;
			pxrem <= pxrem_;
			tuctr <= tuctr_;
			ctr <= ctr_;
			xrem <= xrem_;
			yrem <= yrem_;
			pxfill <= pxfill_;
		end
		if(tufreset)
			tufctr <= tufinc;
		else if(tufstep) begin
			tufctr <= tufctr - {2'd0, tufill, 11'd0} + tufinc;
			tuctr <= tufill;
		end
		
		if(pxcons)
			if(twolane) begin
				px[0] <= px[2];
				px[1] <= px[3];
			end else begin
				px[0] <= px[1];
				px[1] <= px[2];
				px[2] <= px[3];
			end
			
		if(fiforden) begin
			px[pxfill_ - 2] <= fifodo[23:0];
			px[pxfill_ - 1] <= fifodo[47:24];
		end
	end

	always @(*) begin
		pxfill_ = pxfill;
		if(pxcons)
			pxfill_ = pxfill_ - (twolane ? 2 : 1);
		fiforden = !fifoempty && pxfill_ < 3 && !reset;
		if(fiforden)
			pxfill_ = pxfill_ + 2;
	end

	always @(*) begin
		state_ = state;
		hstart_ = hstart && !vstart || dphstart;
		vstart_ = vstart || dpvstart;
		pxrem_ = pxrem;
		tuctr_ = tuctr;
		ctr_ = ctr;
		xrem_ = xrem;
		yrem_ = yrem;
		dpdat0 = 0;
		dpdat1 = 0;
		dpisk0 = 0;
		dpisk1 = 0;
		pxcons = 0;
		tufreset = 0;
		tufstep = 0;
		
		case(state)
		IDLE: begin
			if(vstart_) begin
				if(pxfill >= 3) begin
					state_ = ACTIVE;
					xrem_ = (hact << 1) + hact;
					yrem_ = vact;
					vstart_ = 0;
					hstart_ = 0;
					dpdat0 = {`symBE, 8'b0};
					dpdat1 = {`symBE, 8'b0};
					dpisk0 = 2'b10;
					dpisk1 = 2'b10;
					tufreset = 1;
					tuctr_ = tufincround[16:11];
				end
			end else if(hstart_ && yrem > 0 && pxfill >= 3) begin
				state_ = ACTIVE;
				xrem_ = (hact << 1) + hact;
				ctr_ = 0;
				hstart_ = 0;
				dpdat0 = {`symBE, 8'b0};
				dpdat1 = {`symBE, 8'b0};
				dpisk0 = 2'b10;
				dpisk1 = 2'b10;
				tufreset = 1;
				tuctr_ = tufincround[16:11];
			end else if(hstart_ && yrem == 0) begin
				dpdat0 = {8'h1, `symBS};
				dpdat1 = {8'h1, `symBS};
				dpisk0 = 2'b01;
				dpisk1 = 2'b01;
				ctr_ = 1;
				hstart_ = 0;
				state_ = VBID;
			end
		end
		ACTIVE: begin
			case(pxrem)
			0: begin
				dpdat0 = px[0][15:0];
				dpdat1 = px[1][15:0];
			end
			1: begin
				dpdat0 = px[0][23:8];
				dpdat1 = px[1][23:8];
			end
			2: begin
				dpdat0 = {px[twolane ? 2 : 1][7:0], px[0][23:16]};
				dpdat1 = {px[3][7:0], px[1][7:0]};
			end
			endcase
			ctr_ = ctr + 1;
			if(tuctr == 0 || xrem == 0) begin
				state_ = STUFF;
				dpdat0 = {8'b0, `symFS};
				dpdat1 = {8'b0, `symFS};
				dpisk0 = 2'b01;
				if(xrem == 0) begin
					dpdat0 = {7'b0, yrem == 1, `symBS};
					dpdat1 = {7'b0, yrem == 1, `symBS};
					state_ = VBID;
					ctr_ = 1;
				end else if(ctr == MAXCTR) begin
					dpdat0[15:8] = `symFE;
					dpdat1[15:8] = `symFE;
					dpisk0[1] = 1;
					dpisk1[1] = 1;
					state_ = ACTIVE;
					ctr_ = 0;
				end
			end else if(tuctr == 1 || xrem == 1) begin
				tuctr_ = 0;
				state_ = STUFF;
				pxrem_ = pxrem == 2 ? 0 : pxrem + 1;
				pxcons = pxrem[1];
				xrem_ = xrem - 1;
				if(xrem_ == 0) begin
					state_ = VBID;
					ctr_ = 0;
					dpdat0[15:8] = `symBS;
					dpdat1[15:8] = `symBS;
				end else begin
					dpdat0[15:8] = `symFS;
					dpdat1[15:8] = `symFS;
				end
				dpisk0[1] = 1;
				dpisk1[1] = 1;
			end else begin
				pxrem_ = pxrem == 0 ? 2 : pxrem - 1;
				pxcons = pxrem != 0;
				tuctr_ = tuctr - 2;
				xrem_ = xrem - 2;
			end
		end
		STUFF: begin
			if(ctr == MAXCTR) begin
				dpdat0[15:8] = `symFE;
				dpdat1[15:8] = `symFE;
				dpisk0[1] = 1;
				dpisk1[1] = 1;
				ctr_ = 0;
				state_ = ACTIVE;
				tufstep = 1;
			end else
				ctr_ = ctr + 1;
		end
		VBLANK: begin
			ctr_ = ctr + 1;
			if(twolane)
				case(ctr)
				0: begin
					dpdat0 = {`symSS, `symSS};
					dpdat1 = {`symSS, `symSS};
					dpisk0 = 3;
					dpisk1 = 3;
				end
				1: begin
					dpdat0 = {Mvid[15:8], Mvid[23:16]};
					dpdat1 = {Mvid[15:8], Mvid[23:16]};
				end
				2: begin
					dpdat0 = {htot[15:8], Mvid[7:0]};
					dpdat1 = {hdata[15:8], Mvid[7:0]};
				end
				3: begin
					dpdat0 = {vtot[15:8], htot[7:0]};
					dpdat1 = {vdata[15:8], hdata[7:0]};
				end
				4: begin
					dpdat0 = {hsync[15:8], vtot[7:0]};
					dpdat1 = {vsync[15:8], vdata[7:0]};
				end
				5: begin
					dpdat0 = {Mvid[15:8], Mvid[23:16]};
					dpdat1 = {Mvid[15:8], Mvid[23:16]};
				end
				6: begin
					dpdat0 = {hact[15:8], Mvid[7:0]};
					dpdat1 = {Nvid[23:16], Mvid[7:0]};
				end
				7: begin
					dpdat0 = {vact[15:8], hact[7:0]};
					dpdat1 = {Nvid[7:0], Nvid[15:8]};
				end
				8: begin
					dpdat0 = {8'b00, vact[7:0]};
					dpdat1 = misc;
				end
				9: begin
					dpdat0 = {`symSE, 8'b0};
					dpdat1 = {`symSE, 8'b0};
					dpisk0 = 2'b10;
					dpisk1 = 2'b10;
					ctr_ = 0;
					state_ = IDLE;
				end
				endcase
			else
				case(ctr)
				0: begin
					dpdat0 = {`symSS, `symSS};
					dpisk0 = 3;
				end
				1: dpdat0 = {Mvid[15:8], Mvid[23:16]};
				2: dpdat0 = {htot[15:8], Mvid[7:0]};
				3: dpdat0 = {vtot[15:8], htot[7:0]};
				4: dpdat0 = {hsync[15:8], vtot[7:0]};
				5: dpdat0 = {Mvid[23:16], hsync[7:0]};
				6: dpdat0 = {Mvid[7:0], Mvid[15:8]};
				7: dpdat0 = {hdata[7:0], hdata[15:8]};
				8: dpdat0 = {vdata[7:0], vdata[15:8]};
				9: dpdat0 = {vsync[7:0], vsync[15:8]};
				10: dpdat0 = {Mvid[15:8], Mvid[23:16]};
				11: dpdat0 = {hact[15:8], Mvid[7:0]};
				12: dpdat0 = {vact[15:8], hact[7:0]};
				13: dpdat0 = {8'b0, vact[7:0]};
				14: dpdat0 = {Mvid[23:16], 8'b0};
				15: dpdat0 = {Mvid[7:0], Mvid[15:8]};		
				16: dpdat0 = {Nvid[15:8], Nvid[23:16]};
				17: dpdat0 = {misc[7:0], Nvid[7:0]};
				18: dpdat0 = {8'b0, misc[15:8]};
				19: begin
					dpdat0 = {8'b0, `symSE};
					dpisk0 = 2'b01;
					ctr_ = 0;
					state_ = IDLE;
				end
				endcase
		end
		VBID: begin
			ctr_ = ctr + 2;
			dpisk0 = 0;
			dpisk1 = 0;
			case(ctr % 3)
			0: dpdat0 = {Mvid[7:0], 7'b0, yrem <= 1};
			1: dpdat0 = {8'b0, Mvid[7:0]};
			2: dpdat0 = {7'b0, yrem <= 1, 8'b0};
			endcase
			if(!twolane && (ctr == 10 || ctr == 11) || twolane && (ctr == 4 || ctr == 5)) begin
				ctr_ = 0;
				state_ = EOL;
			end
			dpdat1 = dpdat0;
		end
		EOL: begin
			state_ = yrem == 1 ? VBLANK : IDLE;
			if(yrem != 0)
				yrem_ = yrem - 1;
		end
		endcase
	end

endmodule
