
module div #(
	parameter int DWIDTH = 16,
	parameter int BITPOSWIDTH = $clog2( DWIDTH )
)(
	input  logic clk,
	input  logic rst,
	

	input  logic [ DWIDTH-1:0 ] n,
	input  logic [ DWIDTH-1:0 ] d,
	input  logic in_empty,
	output logic in_rd_en,

	input  logic out_full,
	output logic [ DWIDTH-1:0 ] q,
	output logic out_wr_en
);

	logic pipe_en;

	logic in_valid;

	logic [ DWIDTH-1:0 ] n_r, d_r;
	logic valid_r;
	logic [ BITPOSWIDTH-1:0 ] d_msbpos;

	logic [ DWIDTH-1:0 ] n_dly_r, d_dly_r;
	logic [ BITPOSWIDTH-1:0 ] d_msbpos_r;
	logic valid_dly_r;

	logic [ BITPOSWIDTH-1:0 ] _stages_d_msbpos_out;
	logic [ DWIDTH-1:0 ] stages_n_out, stages_d_out, stages_q_out;
	logic stages_out_valid;
	logic out_valid;

	findmsb_comb #(
		.DWIDTH( DWIDTH ), .BITPOSWIDTH( BITPOSWIDTH )
	) find_d_msb (
		.val( d_r ), .msb_pos( d_msbpos )
	);

	div_stage_group #(
		.DWIDTH( DWIDTH ), .BITPOSWIDTH( BITPOSWIDTH ),
		.STAGES( DWIDTH ), .MIN_DSHAMT( 0 )
	) stages (
		.clk( clk ), .rst( rst ), .pipe_en( pipe_en ),

		.d_msbpos_in( d_msbpos_r ),
		.n_in( n_dly_r ), .d_in( d_dly_r ), .q_in( DWIDTH'( 'h0 ) ),
		.in_valid( valid_dly_r ),

		.d_msbpos_out( _stages_d_msbpos_out ),
		.n_out( stages_n_out ), .d_out( stages_d_out ), .q_out( stages_q_out ),
		.out_valid( stages_out_valid )
	);

	assign pipe_en = ( !out_full );

	assign in_valid = !in_empty;
	assign in_rd_en = pipe_en && in_valid;

	assign q         = stages_q_out;
	assign out_valid = stages_out_valid;
	assign out_wr_en = pipe_en && out_valid;

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			valid_r <= 1'b0;

			valid_dly_r <= 1'b0;
		end
		else if ( pipe_en )
		begin
			valid_r <= in_valid;

			valid_dly_r <= valid_r;
		end

		if ( pipe_en )
		begin
			n_r <= n;
			d_r <= d;

			n_dly_r <= n_r;
			d_dly_r <= d_r;
			d_msbpos_r <= d_msbpos;
		end

	end

endmodule: div

