
module div_stage_group #(
	parameter int DWIDTH = 16,
	parameter int BITPOSWIDTH = $clog2( DWIDTH ),
	parameter int STAGES = 4,
	parameter int MIN_DSHAMT = 0
)(
	input  logic clk,
	input  logic rst,
	input  logic pipe_en,

	input  logic [ BITPOSWIDTH-1:0 ] d_msbpos_in,
	input  logic [ DWIDTH-1:0 ] n_in,
	input  logic [ DWIDTH-1:0 ] d_in,
	input  logic [ DWIDTH-1:0 ] q_in,
	input  logic in_valid,

	output logic [ BITPOSWIDTH-1:0 ] d_msbpos_out,
	output logic [ DWIDTH-1:0 ] n_out,
	output logic [ DWIDTH-1:0 ] d_out,
	output logic [ DWIDTH-1:0 ] q_out,
	output logic out_valid
);

	logic [ STAGES:0 ] [ BITPOSWIDTH-1:0 ] d_msbpos;
	logic [ STAGES:0 ] [ DWIDTH-1:0 ] n, d, q;
	logic [ STAGES:0 ] valid;

	assign d_msbpos[ STAGES ] = d_msbpos_in;
	assign n[ STAGES ] = n_in;
	assign d[ STAGES ] = d_in;
	assign q[ STAGES ] = q_in;
	assign valid[ STAGES ] = in_valid;

	generate
		genvar i;
		for ( i=STAGES-1; i>=0; --i )
		begin
			div_stage #(
				.DWIDTH( DWIDTH ),
				.BITPOSWIDTH( BITPOSWIDTH ),
				.DSHAMT( MIN_DSHAMT + i )
			) stage (
				.clk( clk ), .rst( rst ), .pipe_en( pipe_en ),

				.d_msbpos_in( d_msbpos[ i+1 ] ),
				.n_in( n[ i+1 ] ), .d_in( d[ i+1 ] ), .q_in( q[ i+1 ] ),
				.in_valid( valid[ i+1 ] ),

				.d_msbpos_out( d_msbpos[ i ] ),
				.n_out( n[ i ] ), .d_out( d[ i ] ), .q_out( q[ i ] ),
				.out_valid( valid[ i ] )
			);
		end
	endgenerate

	assign d_msbpos_out = d_msbpos[ 0 ];
	assign n_out = n[ 0 ];
	assign d_out = d[ 0 ];
	assign q_out = q[ 0 ];
	assign out_valid = valid[ 0 ];

endmodule: div_stage_group

