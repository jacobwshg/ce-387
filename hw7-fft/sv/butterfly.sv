
module butterfly
#(
	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14
)
(
	input  logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] w, in1, in2,
	output logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] out1, out2
);

	localparam logic signed [ DATA_WIDTH-1:0 ] Q_STEP = 1 << FRAC_WIDTH;

	localparam logic [ 0:0 ]
		RE = 0,
		IM = 1;

	/*
 	 * Multiplying 2 quantized ints causes overquantization, so we DEQUANTize
 	 * once
 	 */
	function automatic logic signed [ DATA_WIDTH-1:0 ]
	DEQUANT( logic signed [ DATA_WIDTH-1:0 ] qq );
		logic signed [ DATA_WIDTH-1:0 ] q = ( qq + $signed( Q_STEP/2 ) ) / $signed( Q_STEP );
		return q;
	endfunction

	logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] v;

	logic signed [ DATA_WIDTH-1:0 ] rw_r2, iw_i2, rw_i2, iw_r2;

	always_comb
	begin
		// w * in2
		rw_r2 = DEQUANT( w[RE] * in2[RE] );
		iw_i2 = DEQUANT( w[IM] * in2[IM] );
		rw_i2 = DEQUANT( w[RE] * in2[IM] );
		iw_r2 = DEQUANT( w[IM] * in2[RE] );
		v[RE] = rw_r2 - iw_i2;
		v[IM] = rw_i2 + iw_r2;

		out1[RE] = in1[RE] + v[RE];
		out1[IM] = in1[IM] + v[IM];

		out2[RE] = in1[RE] - v[RE];
		out2[IM] = in1[IM] - v[IM];

		/*
		$display( "\nButterfly:" );	
		$display( "\tw: %08h+%08hj, in1: %08h+%08hj, in2: %08h+%08hj", w[RE], w[IM], in1[RE], in1[IM], in2[RE], in2[IM] );
		$display( "\tv[RE] = %08h = %08h - %08h ", v[RE], rw_r2, iw_i2 );
		$display( "\tv[IM] = %08h = %08h - %08h ", v[IM], rw_i2, iw_r2 );
		$display( "\tout1: %08h+%08hj, out2: %08h+%08hj", out1[RE], out1[IM], out2[RE], out2[IM] );
		$display( "" );
		*/

	end

endmodule: butterfly

