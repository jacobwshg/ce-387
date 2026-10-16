
module dq_varshift
#(
	parameter int DWIDTH = 32,
	parameter int LOG2_DWIDTH = $clog2( DWIDTH )
)
(
	input  logic clk,
	input  logic signed [ DWIDTH-1:0 ] din,
	input  logic [ LOG2_DWIDTH-1:0 ] fracwidth,
	output logic signed [ DWIDTH-1:0 ] dout
);

	localparam int SIGN_BIT_POS = DWIDTH - 1;

	logic signed [ DWIDTH-1:0 ] din_r;
	logic [ LOG2_DWIDTH-1:0 ] fracwidth_r;

	logic signed [ DWIDTH-1:0 ] din_dly_r;
	logic signed [ DWIDTH-1:0 ] din_rsh_r;
	logic [ DWIDTH-1:0 ] frac_mask_r;
	logic signed [ DWIDTH-1:0 ] d_dq;

	logic signed [ DWIDTH-1:0 ] dout_r;

	always_ff @ ( posedge clk )
	begin
		din_r <= din;
		fracwidth_r <= fracwidth;

		din_dly_r <= din_r;
		din_rsh_r <= din_r >>> fracwidth_r;
		frac_mask_r <= ( DWIDTH'( 1'b1 ) << fracwidth_r ) - ( DWIDTH'( 1'b1 ) );

		dout_r <= d_dq;
	end

	always_comb
	begin
		d_dq = din_rsh_r;
		if ( din_dly_r[ SIGN_BIT_POS ] && ( $unsigned( din_dly_r ) & frac_mask_r ) )
		begin
			d_dq += DWIDTH'( 1'h1 );
		end
	end

	assign dout = dout_r;

endmodule: dq_varshift

