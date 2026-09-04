
module fromgray_comb
#(
	parameter int DWIDTH = 32
)(
	input  logic [ DWIDTH-1:0 ] g,
	output logic [ DWIDTH-1:0 ] b
);

	// 5 for DWIDTH=32
	localparam int LOG2_DWIDTH = $clog2( DWIDTH );
	localparam int TMP_WIDTH = 2 ** LOG2_DWIDTH;

	logic [ 0:LOG2_DWIDTH ] [ TMP_WIDTH-1:0 ] b_tmp;

	assign b_tmp[ 0 ] = g;
	generate
		genvar log_step;
		for ( log_step=0; log_step<LOG2_DWIDTH; ++log_step )
		begin
			assign b_tmp[ log_step+1 ] =
				b_tmp[ log_step ] ^ (
					b_tmp[ log_step ] >>> ( 2**( log_step ) )
				);
		end
	endgenerate

	assign b = b_tmp[ LOG2_DWIDTH ][ DWIDTH-1:0 ];

endmodule: fromgray_comb

