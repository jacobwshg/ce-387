
`timescale 1 ns / 1 ns

module msb_tb();

	localparam int PERIOD = 10;

	logic clk = 1'b0;
	logic [ 31:0 ] n = 'h0;
	logic [ 5:0 ]  i_msb_bs, i_msb_pe;

	bsrch_32 bs(
		.clk  ( clk ),
		.n    ( n ),
		.i_msb( i_msb_bs )
	);

	pri_enc pe(
		.clk  ( clk ),
		.n    ( n ),
		.i_msb( i_msb_pe )
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
		repeat( 1024 )
		begin
			@ ( negedge clk );
			$strobe( "@ %0t, n = %0d", $time, n );
			n = n + 1;
		end
		$stop;
	end

	always
	begin
		@ ( posedge clk );
		$strobe( "@ %0t, i_msb_bs = %0d, i_msb_pe = %0d", $time, i_msb_bs, i_msb_pe );
	end

endmodule: msb_tb

