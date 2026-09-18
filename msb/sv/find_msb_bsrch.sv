
module find_msb_bsrch
#(
	parameter int DWIDTH = 16
)
(
	input  logic clk,
	input  logic [ DWIDTH-1:0 ] n,
	output logic [ $clog2( DWIDTH )-1:0 ] msb_pos
);

	localparam int BITPOS_WIDTH = $clog2( DWIDTH );
	localparam int TMP_WIDTH = ( 2 ** BITPOS_WIDTH );

	logic [ DWIDTH-1:0 ] n_r;
	logic [ BITPOS_WIDTH-1:0 ] msb_pos_r;

	logic [ BITPOS_WIDTH-1:0 ] msb_pos_tmp;
	logic [ BITPOS_WIDTH-1:0 ] [ TMP_WIDTH-1:0 ] top_half, bottom_half;
	logic [ BITPOS_WIDTH  :0 ] [ TMP_WIDTH-1:0 ] n_tmp;


	always_ff @ ( posedge clk )
	begin
		n_r <= n;
		msb_pos_r <= msb_pos_tmp;
	end

	assign msb_pos = msb_pos_r;

	assign n_tmp[ BITPOS_WIDTH ] = TMP_WIDTH'( n_r );

	generate
		genvar pow;
		for ( pow = BITPOS_WIDTH-1; pow >= 0; --pow )
		begin
			localparam int HALFWIDTH = 2 ** pow;

			assign top_half   [ pow ] = n_tmp[ pow+1 ][ 2*HALFWIDTH-1:HALFWIDTH ];
			assign bottom_half[ pow ] = n_tmp[ pow+1 ][   HALFWIDTH-1:0 ];

			assign msb_pos_tmp[ pow ] = ( | top_half[ pow ] ) ? 1'b1 : 1'b0;

			assign n_tmp[ pow ] = (
				msb_pos_tmp[ pow ] ? ( top_half[ pow ] ) : ( bottom_half[ pow ] )
			);
		end
	endgenerate

endmodule: find_msb_bsrch

