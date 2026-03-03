
//import complex_pkg::*;

module fft_stage1 #(
	parameter int N = 32,
	parameter int DATA_WIDTH = 32
)
(
	input  logic clk,
	input  logic rst,

	input  logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] w,
	input  logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] din,
	input  logic in_valid,

	output logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] dout,
	output logic out_valid
);

	localparam int
		RE = 0,
		IM = 1;

	localparam int STAGE = 1;
	localparam int STEP = 1 << STAGE;
	localparam int HALF_STEP = STEP >> 1;
	localparam int LOG2_N = $clog2( N );

	/* Sample idx = { step idx, lower step flag } */ 
	logic [ LOG2_N:0 ] idx, idx_c;
	logic [ LOG2_N-STAGE:0 ] step_idx;
	/* Sample belongs in upper or lower half of step? (used to determine
 	 * whether butterfly output is valid) */
	logic is_lower_step;

	/* There are no dedicated signals for buffer read/write addrs,
 	 * since the buffer at stage 1 has only a single element */

	/* Butterfly signals (w is constant input) */
	logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ]
		in1, in2, out1, out2;

	butterfly #(
		.DATA_WIDTH( DATA_WIDTH )
	) bf_inst (
		.w( w ),
		.in1( in1 ), .in2( in2 ),
		.out1( out1 ), .out2( out2 )
	);

	logic [ 0:1 ] [ DATA_WIDTH-1:0 ] buff, buff_c;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			buff <= 1'h0;
			idx  <= 1'h0;
		end
		else
		begin
			buff <= buff_c;
//$display( "stage 1 buff_c: ( %h %h )", buff_c[0], buff_c[1] );
			idx  <= idx_c;
		end
	end

	always_comb
	begin
		out_valid = 1'h0;
		dout[0] = 'h0;
		dout[1] = 'h0;

		idx_c = idx;
		{ step_idx, is_lower_step } = { idx[ LOG2_N:1 ], idx[ 0 ] };

		buff_c[0] = 'sh0;
		buff_c[1] = 'sh0;

		/*
		 * Always let butterfly run to cut the critical path delay caused by
		 * its inputs being gated by flags
		 * Its outputs are only sampled in lower steps, when they aren't
		 * garbage
		 *
		 */
		in1 = buff;
		in2 = din;

		$display( "@ %0t, stage1 butterfly in1 = buff = { %08h, %08h ), in2 = din = ( %08h, %08h ) ", $time, buff[0], buff[1], din[0], din[1] );

		if ( in_valid )
		begin
			$display( "stage1 butterfly (in valid): w: %h+%hj, in1: %h+%hj, in2: %h+%hj, out1: %h+%hj, out2: %h+%hj", w[RE], w[IM], in1[RE], in1[IM], in2[RE], in2[IM], out1[RE], out1[IM], out2[RE], out2[IM] );

			out_valid = ( ( step_idx==0 ) & ~is_lower_step ) ? 1'h0 : 1'h1;

			$display( "                             idx %8bb, step_idx %d, is_lower_step %b, out_valid: %1b", idx, step_idx, is_lower_step, out_valid );

			idx_c = idx + 1;
			if ( is_lower_step )
			begin
				/*
				 * Buffer upstream input as butterfly's first input,
				 * and output previous butterfly's second output if there is one
				 */
$display(" stage1 lower step, assigning din ( %h %h ) to buff_c ", din[0], din[1] );
				buff_c = din;
				dout   = buff;
			end
			else
			begin
				/*
				 * Butterfly is complete; output butterfly's first output and
				 * buffer its second output
				 */
				buff_c = out2;
				dout   = out1;
			end


		end
	end

endmodule: fft_stage1

