
import globals_pkg :: N;
import globals_pkg :: DWIDTH;
import globals_pkg :: printtime;
import twdls_pkg :: TWDLS;

module fft_stage1 #(
	parameter int N = globals_pkg::N,
	parameter int DWIDTH = globals_pkg::DWIDTH,
	parameter logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		STAGE1_TWDL = twdls_pkg::TWDLS[ 0 ][ 0 ]
)
(
	input  logic clk,
	input  logic rst,

	// fixed twiddle factor
	input  logic signed [ 0:1 ] [ DWIDTH-1:0 ] din,
	input  logic in_empty,
	input  logic out_full,

	output logic in_rd_en,
	output logic signed [ 0:1 ] [ DWIDTH-1:0 ] dout,
	output logic out_wr_en
);
	import quant_pkg::DEQUANT;

	localparam int STAGE = 1;

	localparam int
		RE = 0,
		IM = 1;

	/*
	 * 1-based stage index
	 * Stage 2: step = 4
	 * Stage 3: step = 8
	 */ 
	localparam int STEP = 1 << STAGE;
	localparam int HALF_STEP = STEP >> 1;
	localparam int LOG2_N = $clog2( N );

	typedef enum logic [ 2:0 ]
	{
		S_FETCH, S_BF_MUL, 
		S_BF_DQ,
		S_BF_OUT
	} fsm_state_t;
	fsm_state_t fsm_state, fsm_state_c;

	/* Sample idx = { step idx, lower step flag } */ 
	logic [ LOG2_N:0 ] sampl_idx, sampl_idx_c;

	/* Index of current step */
	logic [ LOG2_N-STAGE:0 ] step_idx;
	/* Sample belongs in former or latter half of step? 
 	 * ( when the incoming sample is in the former half step, we ignore
 	 * the butterfly and output the previous butterfly's out2 from buffer;
 	 * but when we're in step 0, there is no prev butterfly and our
 	 * module output is invalid ) 
 	 */
	logic is_latter_hstep;
	logic out_valid;

	/* There are no dedicated signals for buffer read/write addrs,
 	 * since the buffer at stage 1 has only a single element */

	/* Butterfly and buffer signals */
	logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		in1,
		w,
		out1, out2,
		dly_buf, dly_buf_c;
	logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		in2, in2_c,
		v, v_c;

	/* intermediate results */
	logic signed [ DWIDTH-1:0 ]
		prod_wr_i2r, prod_wr_i2r_c,
		prod_wi_i2i, prod_wi_i2i_c,
		prod_wr_i2i, prod_wr_i2i_c,
		prod_wi_i2r, prod_wi_i2r_c;

	assign step_idx = sampl_idx[ LOG2_N:STAGE ];
	assign is_latter_hstep = sampl_idx[ STAGE-1 ];

	assign out_valid = step_idx!==0 || is_latter_hstep;
	/*
 	 * In former half step, read back buffered out2 and send it downstream,
 	 * buffer in1
 	 * In latter half step, read back buffered in1, run butterfly, overwrite
 	 * in1 with out2 at same half-step addr in buffer
	 */

	assign w = STAGE1_TWDL;

	always_comb
	begin
		fsm_state_c = fsm_state;

		in_rd_en = 1'b0;
		out_wr_en = 1'b0;
		dout[ RE ] = 'shX;
		dout[ IM ] = 'shX;

		dly_buf_c[ RE ] = dly_buf[ RE ];
		dly_buf_c[ IM ] = dly_buf[ IM ];

		sampl_idx_c = sampl_idx;

		in2_c[ RE ] = in2[ RE ];
		in2_c[ IM ] = in2[ IM ];
		v_c  [ RE ] = v  [ RE ];
		v_c  [ IM ] = v  [ IM ];

		prod_wr_i2r_c = prod_wr_i2r;
		prod_wr_i2i_c = prod_wr_i2i;
		prod_wi_i2i_c = prod_wi_i2i;
		prod_wi_i2r_c = prod_wi_i2r;

		in1  = '{ default: 'shX };
		out1 = '{ default: 'shX };
		out2 = '{ default: 'shX };

		case ( fsm_state )
			S_FETCH:
			begin
				if ( !in_empty )
				begin
					in_rd_en = 1'b1;
					in2_c = din;

					prod_wr_i2r_c = w[ RE ] * in2_c[ RE ];
					prod_wr_i2i_c = w[ RE ] * in2_c[ IM ];
					prod_wi_i2i_c = w[ IM ] * in2_c[ IM ];
					prod_wi_i2r_c = w[ IM ] * in2_c[ RE ];

					$display( "stage1 read piped ROB data %016h", din );
					//$display( "\tw r*r: %08h, dq: %08h", prod_wr_i2r_c, quant_pkg::DEQUANT( prod_wr_i2r_c ) );
					//$display( "\tw r*i: %08h, dq: %08h", prod_wr_i2i_c, quant_pkg::DEQUANT( prod_wr_i2i_c ) );
					//$display( "\tw i*i: %08h, dq: %08h", prod_wi_i2i_c, quant_pkg::DEQUANT( prod_wi_i2i_c ) );
					//$display( "\tw i*r: %08h, dq: %08h", prod_wi_i2r_c, quant_pkg::DEQUANT( prod_wi_i2r_c ) );

					fsm_state_c = S_BF_OUT;
				end
			end

			S_BF_MUL:
			begin
				fsm_state_c = S_BF_OUT;
			end

			/*
			S_BF_DQ:
			begin
				prod_wr_i2r_c = quant_pkg::DEQUANT( prod_wr_i2r );
				prod_wr_i2i_c = quant_pkg::DEQUANT( prod_wr_i2i );
				prod_wi_i2i_c = quant_pkg::DEQUANT( prod_wi_i2i );
				prod_wi_i2r_c = quant_pkg::DEQUANT( prod_wi_i2r );
				fsm_state_c = S_BF_OUT;
			end
			*/

			S_BF_OUT:
			begin
				if ( !out_full )
				begin

					//printtime();
					//$display( "sample idx %08b", sampl_idx );

					if ( !is_latter_hstep )
					begin
						//
						// former half step
						//

						//$display( "stage 1 former half step, buffering input data %08h + %08hj", in2[ RE ], in2[ IM ] );
						dout      = dly_buf;
						dly_buf_c = in2;
					end
					else
					begin
						//
						// latter half step
						//
						in1        = dly_buf;
						v_c[ RE ]  = quant_pkg::DEQUANT( prod_wr_i2r ) - quant_pkg::DEQUANT( prod_wi_i2i );
						v_c[ IM ]  = quant_pkg::DEQUANT( prod_wr_i2i ) + quant_pkg::DEQUANT( prod_wi_i2r );
						//v_c [ RE ] = prod_wr_i2r - prod_wi_i2i;
						//v_c [ IM ] = prod_wr_i2i + prod_wi_i2r
;
						out1[ RE ] = in1[ RE ] + v_c[ RE ];
						out1[ IM ] = in1[ IM ] + v_c[ IM ];
						out2[ RE ] = in1[ RE ] - v_c[ RE ];
						out2[ IM ] = in1[ IM ] - v_c[ IM ];

						dout      = out1;
						dly_buf_c = out2;

						///*
						$display( "stage 1 latter half step, step idx %0d", step_idx );
						$display( "\tw = %08h + %08hj", w[ RE ], w[ IM ] );
						$display( "\tin1 = %08h + %08hj, in2 = %08h + %08hj", in1[ RE ], in1[ IM ], in2[ RE ], in2[ IM ] );
						$display( "\tout1 = %08h + %08hj, out2 = %08h + %08hj", out1[ RE ], out1[ IM ], out2[ RE ], out2[ IM ] );
						$display( "" );
						//*/

					end

					out_wr_en = out_valid? 1'b1: 1'b0;

					if ( out_wr_en )
					begin
						// `out1` was once misused for the format parameters
						// instead of `dout`. they are the same only in latter 
						// half steps. however, in former half steps, `out1`
						// was shown to be the same as the prev butterfly's
						// `in1`. it should've been the sum of `in` with a
						// previous nonzero `v`, so why?
						$display( "stage %0d outputting data %08h+%08hj", STAGE, out1[ RE ], out1[ IM ] );
					end

					sampl_idx_c = sampl_idx + 1'h1;
					fsm_state_c = S_FETCH;
				end

			end

		endcase

	end

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			fsm_state <= S_FETCH;

			dly_buf[ RE ] <= 'sh0;
			dly_buf[ IM ] <= 'sh0;

			sampl_idx <= 'h0;

			in2[ RE ] <= 'sh0;
			in2[ IM ] <= 'sh0;
			v  [ RE ] <= 'sh0;
			v  [ IM ] <= 'sh0;

			prod_wr_i2r <= 'sh0;
			prod_wi_i2i <= 'sh0;
			prod_wr_i2i <= 'sh0;
			prod_wi_i2r <= 'sh0;
		end
		else
		begin
			fsm_state <= fsm_state_c;

			dly_buf[ RE ] <= dly_buf_c[ RE ];
			dly_buf[ IM ] <= dly_buf_c[ IM ];

			sampl_idx <= sampl_idx_c;

			in2[ RE ] <= in2_c[ RE ];
			in2[ IM ] <= in2_c[ IM ];
			v  [ RE ] <= v_c  [ RE ];
			v  [ IM ] <= v_c  [ IM ];

			prod_wr_i2r <= prod_wr_i2r_c;
			prod_wi_i2i <= prod_wi_i2i_c;
			prod_wr_i2i <= prod_wr_i2i_c;
			prod_wi_i2r <= prod_wi_i2r_c;
		end
	end

endmodule: fft_stage1

