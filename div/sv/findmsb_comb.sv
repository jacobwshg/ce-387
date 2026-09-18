
module findmsb_bsrch_comb
#(
	parameter int DWIDTH = 16,
	parameter int BITPOSWIDTH = $clog2( DWIDTH )
)
(
	input  logic [ DWIDTH-1:0 ] val,
	output logic [ BITPOSWIDTH-1:0 ] msb_pos
);

	localparam int TMP_WIDTH = 2 ** BITPOSWIDTH;

	logic [ BITPOSWIDTH-1:0 ] msb_pos_tmp;
	logic [ BITPOSWIDTH-1:0 ] [ TMP_WIDTH-1:0 ] top_half, bottom_half;
	logic [ BITPOSWIDTH  :0 ] [ TMP_WIDTH-1:0 ] val_tmp;

	assign val_tmp[ BITPOSWIDTH ] = val;

	generate
		genvar pow;
		for ( pow = BITPOSWIDTH-1; pow >= 0; --pow )
		begin
			localparam int HALFWIDTH = 2 ** pow;

			assign top_half   [ pow ] = val_tmp[ pow+1 ][ 2*HALFWIDTH-1:HALFWIDTH ];
			assign bottom_half[ pow ] = val_tmp[ pow+1 ][   HALFWIDTH-1:0 ];

			assign msb_pos_tmp[ pow ] = ( | top_half[ pow ] ) ? 1'b1 : 1'b0;

			assign val_tmp[ pow ] = (
				msb_pos_tmp[ pow ] ? ( top_half[ pow ] ) : ( bottom_half[ pow ] )
			);
		end
	endgenerate

	assign msb_pos = msb_pos_tmp;

endmodule: findmsb_bsrch_comb

module findmsb_comb
#(
	parameter int DWIDTH = 16,
	parameter int BITPOSWIDTH = $clog2( DWIDTH )
)
(
	input  logic [ DWIDTH-1:0 ] val,
	output logic [ BITPOSWIDTH-1:0 ] msb_pos
);

	function automatic logic [ BITPOSWIDTH-1:0 ]
	FINDMSB_LINEAR( input logic [ DWIDTH-1:0 ] val );
		for ( int pos = DWIDTH-1; pos >= 0; --pos )
		begin
			if ( val[ pos ] === 1'b1 )
			begin
				return pos;
			end
		end
		return BITPOSWIDTH'( 'h0 );
	endfunction: FINDMSB_LINEAR

	generate
		if ( DWIDTH <= 32 )
		begin
			assign msb_pos = FINDMSB_LINEAR( val );
		end
		else
		begin
			findmsb_bsrch_comb #(
				.DWIDTH( DWIDTH ), .BITPOSWIDTH( BITPOSWIDTH )
			) bsrch (
				.val( val ), .msb_pos( msb_pos )
			);
		end
	endgenerate

endmodule: findmsb_comb

