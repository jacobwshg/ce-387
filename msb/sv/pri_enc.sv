
module pri_enc
#(
	parameter DWIDTH = 32
)
(
	input  logic clk,
	input  logic [ DWIDTH-1:0 ] n,
	output logic [ $clog2( DWIDTH ):0 ] i_msb
);

	logic [ DWIDTH-1:0 ] n_ff;
	logic [ $clog2( DWIDTH ):0 ] i_msb_ff;

	function automatic logic [ $clog2( DWIDTH ):0 ]
	getmsb( input logic [ DWIDTH-1:0 ] val );
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
		n_ff     <= n;
		i_msb_ff <= getmsb( n_ff );
	end

	assign i_msb = i_msb_ff;

endmodule: pri_enc

