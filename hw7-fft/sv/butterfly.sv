
module butterfly
#(
	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14
)
(
	input  logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] w, in1, in2,
	output logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] out1, out2
);

	localparam logic [ 0:0 ]
		RE = 0,
		IM = 1;

	/*
 	 * Multiplying 2 quantized ints causes overquantization, so we dequantize
 	 * once
 	 */
	function automatic logic signed [ DATA_WIDTH-1:0 ]
	dequant( logic signed [ DATA_WIDTH-1:0 ] qq );
		logic signed [ DATA_WIDTH-1:0 ] q = qq + $signed( 1 << (FRAC_WIDTH-1) ) / $signed(1 << FRAC_WIDTH);
		return q;
	endfunction

	logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] v;

	always_comb
	begin
		// w * in2
		v[RE] = dequant( w[RE] * in2[RE] ) - dequant( w[IM] * in2[IM] );
		v[IM] = dequant( w[RE] * in2[IM] ) + dequant( w[IM] * in2[RE] );

		out1[RE] = in1[RE] + v[RE];
		out1[IM] = in1[IM] + v[IM];

		out2[RE] = in1[RE] - v[RE];
		out2[IM] = in1[IM] - v[IM];

		$display( "butterfly: in1: %h+%hj, in2: %h+%hj, w: %h+%hj, out1: %h+%hj, out2: %h+%hj", in1[RE], in1[IM], in2[RE], in2[IM], w[RE], w[IM], out1[RE], out1[IM], out2[RE], out2[IM] );

	end

endmodule: butterfly

