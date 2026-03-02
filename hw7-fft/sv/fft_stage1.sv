
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
	localparam int STAGE = 1;
	localparam int STEP = 1 << STAGE;
	localparam int HALF_STEP = STEP >> 1;
	localparam int LOG2_N = $clog2( N );

	/* Clocked in_valid (in case upstream flips in_valid mid-cycle) */
	logic valid;
	/* Sample idx = { step idx, lower step flag } */ 
	logic [ LOG2_N:0 ] idx, idx_c;
	logic [ LOG2_N-STAGE:0 ] step_idx;
	/* Sample belongs in upper or lower half of step? (used to determine
 	 * whether butterfly output is valid) */
	logic is_lower_step;

	/* There are no dedicated signals for buffer read/write addrs,
 	 * since the buffer at stage 1 has only a single element */

	/* Butterfly signals */
	logic [ 0:1 ] [ DATA_WIDTH-1:0 ]
		in1, in2, out1, out2, w;

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
			valid <= 1'h0;
		end
		else
		begin
			buff <= buff_c;
			idx  <= idx_c;
			valid <= in_valid;
		end
	end

	always_comb
	begin
		out_valid = 1'h0;

		{ step_idx, is_lower_step } = { idx[ LOG2_N:1 ], idx[ 0 ] };

		/*
		 * Always let butterfly run to cut the critical path delay caused by
		 * its inputs being gated by flags
		 * Its outputs are only sampled in lower steps, when they aren't
		 * garbage
		 *
		 */
		in1 = buff;
		in2 = din;

		if ( valid )
		begin
			out_valid = ( ( step_idx==0 ) & ~is_lower_step ) ? 1'h0 : 1'h1;

			idx_c += 1;
			if ( is_lower_step )
			begin
				/*
				 * Buffer upstream input as butterfly's first input,
				 * and output previous butterfly's second output if there is one
				 */
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

