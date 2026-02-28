
import my_complex::*;

module butterfly
#(
	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14
)
(
	input clk,
	input rst,

	input complex_t w,
	input complex_t in1,
	input complex_t in2,

	output complex_t out1,
	output complex_t out2
);
	/*
 	 * Multiplying 2 quantized ints causes overquantization, so we dequantize
 	 * once
 	 */
	function automatic logic signed [ 31:0 ]
	dequant( logic signed [ 31:0 ] i );
		return ( i + ( 1 << (FRAC_WIDTH-1) ) ) >>> FRAC_WIDTH;
	endfunction

	complex_t v, out1_c, out2_c;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			out1 <= { 32'h0, 32'h0 };
			out2 <= { 32'h0, 32'h0 };
		end
		else
		begin
			out1 <= out1_c;
			out2 <= out2_c;
		end
	end

	always_comb
	begin
		// w * in2
		v[ I_RE ] = dequant( w[ I_RE ] * in2[ I_RE ] ) - dequant( w[ I_IM ] * in2[ I_IM ] );
		v[ I_IM ] = dequant( w[ I_RE ] * in2[ I_IM ] ) + dequant( w[ I_IM ] * in2[ I_RE ] );

		out1_c[ I_RE ] = in1[ I_RE ] + v[ I_RE ];
		out1_c[ I_IM ] = in1[ I_IM ] + v[ I_IM ];

		out2_c[ I_RE ] = in1[ I_RE ] - v[ I_RE ];
		out2_c[ I_IM ] = in1[ I_IM ] - v[ I_IM ];
	end

endmodule: butterfly

