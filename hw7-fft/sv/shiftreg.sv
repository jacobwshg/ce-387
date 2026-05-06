
module shiftreg #(
	parameter int WIDTH  = 16,
	parameter int DWIDTH = 32
)(
	input  logic clk,
	input  logic sh_en,
	input  logic [ DWIDTH-1:0 ] din,
	output logic [ DWIDTH-1:0 ] dout
);

	logic [ DWIDTH-1:0 ] buff [ 0:WIDTH-1 ];

	always_ff @ ( posedge clk )
	begin
		dout <= buff[ WIDTH-1 ];
		if ( sh_en )
		begin
			buff[ 0 ] <= din;
			buff[ 1:WIDTH-1 ] <= buff[ 0:WIDTH-2 ];
		end
	end

	//assign dout = buff[ WIDTH-1 ];

endmodule: shiftreg

