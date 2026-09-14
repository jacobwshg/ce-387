
module pri_enc
#(
	parameter DWIDTH = 32
)
(
	input  logic clk,
	input  logic [ DWIDTH-1:0 ] n,
	output logic [ $clog2( DWIDTH ):0 ] msb_pos
);

	logic [ DWIDTH-1:0 ] n_r;
	logic [ $clog2( DWIDTH ):0 ] msb_pos_r;

	function automatic logic [ $clog2( DWIDTH ):0 ]
	findmsb( input logic [ DWIDTH-1:0 ] val );
		for ( int i = DWIDTH-1; i >= 0; --i )
		begin
			if ( val[ i ] === 1'b1 )
			begin
				return i;
			end
		end
		return 'h0;
	endfunction

	always_ff @ ( posedge clk )
	begin
		n_r <= n;
		msb_pos_r <= findmsb( n_r );
	end

	assign msb_pos = msb_pos_r;

endmodule: pri_enc

