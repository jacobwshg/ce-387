
`timescale 1 ns / 1 ns

module msb_tb #(
	parameter int DWIDTH = 32,
	parameter int N_MAX = 512

)();

	localparam int PERIOD = 10;

	logic clk = 1'b0;
	logic [ 31:0 ] n = 'h0;
	logic [ 5:0 ]  msb_pos_bs, msb_pos_pe;

	find_msb_bsrch
	#(
		.DWIDTH( DWIDTH )
	) bsrch (
		.clk( clk ),
		.n( n ),
		.msb_pos( msb_pos_bs )
	);

	pri_enc #(
		.DWIDTH( DWIDTH )
	)
	pe (
		.clk( clk ),
		.n( n ),
		.msb_pos( msb_pos_pe )
	);

	always
	begin
		#( PERIOD/2 );
		clk = 1'b1;
		#( PERIOD/2 );
		clk = 1'b0;
	end

	initial
	begin
		for ( n=0; n<=N_MAX; ++n )
		begin
			@ ( negedge clk );
			$strobe( "@ %0t, n = %0d", $time, n );
		end
		#( PERIOD*2 );
		$stop;
	end

	always
	begin
		@ ( posedge clk );
		$strobe( "@ %0t, msb_pos_bs = %0d, msb_pos_pe = %0d", $time, msb_pos_bs, msb_pos_pe );
	end

endmodule: msb_tb

