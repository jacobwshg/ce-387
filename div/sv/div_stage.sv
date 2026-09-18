
module div_stage #(
	parameter int DWIDTH = 16,
	parameter int BITPOSWIDTH = $clog2( DWIDTH ),
	parameter int DSHAMT = DWIDTH-1
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

	logic [ BITPOSWIDTH-1:0 ] d_msbpos_r;
	logic [ DWIDTH-1:0 ] n_r;
	logic [ DWIDTH-1:0 ] d_r;
	logic [ DWIDTH-1:0 ] d_lsh_r;
	logic [ DWIDTH-1:0 ] q_r;
	logic [ DWIDTH-1:0 ] r_r;
	logic valid_r;
	logic [ DWIDTH-1:0 ] n_tmp;
	logic [ DWIDTH-1:0 ] q_tmp;

	logic [ BITPOSWIDTH-1:0 ] d_msbpos_out_r;
	logic [ DWIDTH-1:0 ] n_out_r;
	logic [ DWIDTH-1:0 ] d_out_r;
	logic [ DWIDTH-1:0 ] q_out_r;
	logic out_valid_r;

	always_ff @( posedge clk )
	begin
		if ( rst )
		begin
			valid_r <= 1'b0;

			out_valid_r <= 1'b0;
		end
		else if ( pipe_en )
		begin
			valid_r <= in_valid;

			out_valid_r <= valid_r;
		end

		if ( pipe_en )
		begin
			d_msbpos_r <= d_msbpos_in;
			n_r     <= n_in;
			d_r     <= d_in;
			d_lsh_r <= d_in << DSHAMT;
			q_r     <= q_in;
			/* 
			 * Underflow is possible, but in these cases we discard the
			 * subtraction result and pass the same n to the next stage 
		 	 */ 
			r_r     <= n_in - ( d_in << DSHAMT );
	
			d_msbpos_out_r <= d_msbpos_r;
			n_out_r <= n_tmp;
			d_out_r <= d_r;
			q_out_r <= q_tmp;
		end
	end

	assign d_msbpos_out = d_msbpos_out_r;
	assign n_out = n_out_r;
	assign d_out = d_out_r;
	assign q_out = q_out_r;
	assign out_valid = out_valid_r;

	always_comb
	begin
		//d_lsh = d_in << DSHAMT;

		n_tmp = n_r;
		q_tmp = q_r;
		if ( int'( d_msbpos_r ) >= DWIDTH - DSHAMT )
		begin
			/* d overflows after upscaling; no implication on quotient */
			/* do nothing */
		end
		else if ( n_r >= d_lsh_r )
		begin
			//n_tmp = n_r - d_lsh_r;
			n_tmp = r_r;
			q_tmp = q_r | ( DWIDTH'( 1'h1 ) << DSHAMT );
		end
	end

endmodule: div_stage

