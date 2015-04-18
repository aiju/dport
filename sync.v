module sync(
	input wire clk,
	input wire din,
	output wire dout
);

	(* shreg_extract = "no", ASYNC_REG = "TRUE" *) reg d0, d1;
	
	always @(posedge clk) begin
		d0 <= din;
		d1 <= d0;
	end
	
	assign dout = d1;

endmodule
