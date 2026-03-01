
import complex_pkg::*;

module fft_stage #(
	parameter int STAGE, // START AT 1
	parameter int N = 32,
	parameter int DATA_WIDTH = 32
)
(
	input  logic clk,
	input  logic rst,

	input  logic signed [ 0:N-1 ] [ 0:1 ] [ DATA_WIDTH-1:0 ] stage_twdls,
	input  logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] din,
	input  logic in_valid,

	output logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] dout,
	output logic out_valid
);
	/*
	* Stage 1: step 2
	* Stage 2: step 4
	* Stage 3: step 8
	*/ 
	localparam int STEP = 1 << STAGE;
	localparam int HALF_STEP = STEP >> 1;
	localparam int LOG2_N = $clog2( N );

	/* Clocked in_valid (in case upstream flips in_valid mid-cycle) */
	logic valid;
	/* Sample idx = { step idx, buf sample addr } */ 
	logic [ LOG2_N:0 ] idx, idx_c;
	/* Buffer read/write addrs; we only buffer a half step */
	logic [ ( STAGE==1? 0: STAGE-2 ):0 ] wr_addr, rd_addr;
	/* Step idx - has an extra high bit to accommodate final stage, 
	 * which has a single step but step idx couldn't possibly be 0-bit wide
	 */
	logic [ LOG2_N-STAGE:0 ] step_idx;
	/* Sample belongs in upper or lower half of step? */
	logic is_lower_step;

	/* Butterfly and buffer */
	logic [ 0:1 ] [ DATA_WIDTH-1:0 ]
		in1, in2, out1, out2, w,
		buf_din, buf_dout;

	butterfly #(
		.DATA_WIDTH( DATA_WIDTH )
	) bf_inst (
		.w( w ), .in1( in1 ), .in2( in2 ),
		.out1( out1 ), .out2( out2 )
	);

	bram #(
		.BRAM_ADDR_WIDTH( STAGE-1 ),
		.BRAM_DATA_WIDTH( 2 * DATA_WIDTH )
	) buff (
		.clock  ( clk ),
		.reset  ( rst ),
		.rd_addr( rd_addr ),
		.wr_addr( wr_addr ),
		.wr_en  ( valid ),
		.din    ( buf_din ),
		.dout   ( buf_dout )
	); 

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			idx <= 1'h0;
			valid <= 1'h0;
		end
		else
		begin
			idx <= idx_c;
			valid <= in_valid;
		end
	end

	always_comb
	begin
		out_valid = 1'h0;
		step_idx = idx[ LOG2_N -: STAGE ];

		wr_addr = idx[ ( STAGE==1? 0: STAGE-2 ):0 ];
		rd_addr = 1'h0;
		/*
		 * Ex: stage 2 has step 4, half-step 2. sample addrs ..<0>0, ..<0>1 
		 * are in upper step (don't use butterfly), sample addrs ..<1>0, 
		 * ..<1>1 are in lower step (use butterfly)
		 */
		is_lower_step = idx[ STAGE-1 ];

		/*
		 * Always let butterfly run to cut the critical path delay caused by
		 * its inputs being gated by flags
		 * Its outputs are only sampled in lower steps, when they aren't
		 * garbage
		 *
		 */
		w = stage_twdls[ wr_addr ];
		in1 = buf_dout;
		in2 = din;

		if ( valid )
		begin
			out_valid = ( ( step_idx==0 ) & ~is_lower_step ) ? 1'h0 : 1'h1;

			idx_c += 1;
			/*
			 * The buffer read addr should be such that after the next clk edge,
			 * the data returned from buffer (in1) can pair with the new incoming 
			 * data (in2)
			 */
			rd_addr = STAGE==1 ? 1'h0 : wr_addr + 1 - HALF_STEP;
			if ( is_lower_step )
			begin
				/*
				 * Buffer upstream input as butterfly's first input,
				 * and output previous butterfly's second output if there is one
				 */
				buf_din = din;
				dout    = buf_dout;
			end
			else
			begin
				/*
				 * Butterfly is complete; output butterfly's first output and
				 * buffer its second output
				 */
				buf_din = out2;
				dout    = out1;
			end
		end
	end

endmodule: fft_stage

