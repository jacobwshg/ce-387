
import globals_pkg :: N;
import globals_pkg :: DWIDTH;
import globals_pkg :: printtime;
import twdls_pkg :: TWDLS;

module fft_stage #(
	parameter int STAGE = 2,
	parameter int N = globals_pkg::N,
	parameter int DWIDTH = globals_pkg::DWIDTH,

	parameter logic signed [ 0:(1<<( STAGE-1 ) )-1 ] [ 0:1 ] [ DWIDTH-1:0 ]
		STAGE_TWDLS =
		twdls_pkg::TWDLS [ STAGE-1 ] [ 0:( 1<<( STAGE-1 ) )-1 ]
)
(
	input  logic clk,
	input  logic rst,

	input  logic signed [ 0:1 ] [ DWIDTH-1:0 ] din,
	input  logic in_empty,
	input  logic out_full,

	output logic in_rd_en,
	output logic signed [ 0:1 ] [ DWIDTH-1:0 ] dout,
	output logic out_wr_en
);
	import quant_pkg::DEQUANT;

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

	/* Sample idx = { step idx, lower step flag, buf sample addr } */ 
	logic [ LOG2_N:0 ] sampl_idx, sampl_idx_c;
	/* Step sampl_idx - has an extra high bit to accommodate final stage, 
	 * which has all samples within a single step but step sampl_idx couldn't possibly 
	 * be 0-bit wide. Also, it needs to enter a higher "ghost step" to flush the
	 * pipeline.
	 */
	logic [ LOG2_N-STAGE:0 ] step_idx;
	/* Sample belongs in former or latter half of step? 
 	 * ( when the incoming sample is in the former half step, we ignore
 	 * the butterfly and output the previous butterfly's out2 from buffer;
 	 * but when we're in step 0, there is no prev butterfly and our
 	 * module output is invalid ) step
 	 */
	logic is_latter_hstep;
	logic out_valid;

	/* Read/write addrs for delay buffer; buffering half a step is enough */
	logic [ STAGE-2:0 ] buf_rd_addr, buf_wr_addr;

	/* Butterfly and buffer signals */
	logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		in1,
		out1, out2,
		w,
		buf_din, buf_dout;
	logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		in2, in2_c,
		v, v_c;

	logic buf_wr_en;

	/* intermediate results */
	logic signed [ DWIDTH-1:0 ]
		prod_wr_i2r, prod_wr_i2r_c,
		prod_wi_i2i, prod_wi_i2i_c,
		prod_wr_i2i, prod_wr_i2i_c,
		prod_wi_i2r, prod_wi_i2r_c;

	bram #(
		.BRAM_ADDR_WIDTH( STAGE-1 ),
		.BRAM_DATA_WIDTH( 2 * DWIDTH )
	) dly_buf (
		.clock  ( clk ),

		.rd_addr( buf_rd_addr ),
		.wr_addr( buf_wr_addr ),

		.wr_en  ( buf_wr_en ),

		.din    ( buf_din ),
		.dout   ( buf_dout )
	); 

	assign { step_idx, is_latter_hstep, buf_rd_addr }
		= { sampl_idx[ LOG2_N:STAGE ], sampl_idx[ STAGE-1 ], sampl_idx[ STAGE-2:0 ] };

	// if we're in step 0, only the latter half step's output ( which is
	// butterfly 0's out1 ) is valid
	assign out_valid = step_idx!==0 || is_latter_hstep;
	/*
 	 * In former half step, read back buffered out2 and send it downstream,
 	 * buffer in1
 	 * In latter half step, read back buffered in1, run butterfly, overwrite
 	 * in1 with out2 at same half-step addr in buffer
	 */
	assign buf_wr_addr = buf_rd_addr;

	always_ff @ ( posedge clk )
	begin: rd_twdl
		//
		// read a twiddle factor. buf_rd_addr is part of sampl_idx,
		// which is updated on the clk edge between S_BF_OUT and S_FETCH.
		// the read from the new edge happens on the clk edge
		// between S_FETCH and S_BF_MUL ( assuming no stall ).
		//
		w <= STAGE_TWDLS[ buf_rd_addr ];
	end: rd_twdl

	always_comb
	begin
		fsm_state_c = fsm_state;

		in_rd_en = 1'b0;
		out_wr_en = 1'b0;
		dout[ RE ] = 'shX;
		dout[ IM ] = 'shX;

		buf_din[ RE ] = 'shX;
		buf_din[ IM ] = 'shX;
		buf_wr_en = 1'b0;

		sampl_idx_c = sampl_idx;

		in2_c[ RE ] = in2[ RE ];
		in2_c[ IM ] = in2[ IM ];
		v_c  [ RE ] = v  [ RE ];
		v_c  [ IM ] = v  [ IM ];

		prod_wr_i2r_c = prod_wr_i2r;
		prod_wi_i2i_c = prod_wi_i2i;
		prod_wr_i2i_c = prod_wr_i2i;
		prod_wi_i2r_c = prod_wi_i2r;

		in1  = '{ default: 'sh0 };
		out1 = '{ default: 'sh0 };
		out2 = '{ default: 'sh0 };

		case ( fsm_state )
			S_FETCH:
			begin
				if ( !in_empty )
				begin
					in_rd_en = 1'b1;

					in2_c = din;

					// only run butterfly if in latter half step
					fsm_state_c = is_latter_hstep
						? S_BF_MUL
						: S_BF_OUT;
				end
			end

			S_BF_MUL:
			begin
				prod_wi_i2r_c = w[ IM ] * in2[ RE ];
				prod_wi_i2i_c = w[ IM ] * in2[ IM ];
				prod_wr_i2r_c = w[ RE ] * in2[ RE ];
				prod_wr_i2i_c = w[ RE ] * in2[ IM ];
				fsm_state_c = S_BF_DQ;
			end

			S_BF_DQ:
			begin
				prod_wr_i2r_c = quant_pkg::DEQUANT( prod_wr_i2r );
				prod_wi_i2i_c = quant_pkg::DEQUANT( prod_wi_i2i );
				prod_wr_i2i_c = quant_pkg::DEQUANT( prod_wr_i2i );
				prod_wi_i2r_c = quant_pkg::DEQUANT( prod_wi_i2r );
				fsm_state_c = S_BF_OUT;
			end

			// keep
			S_BF_OUT:
			begin
				if ( !out_full )
				begin
					if ( !is_latter_hstep )
					begin
						//
						// former half step
						//

						// output prev butterfly's buffered out2
						dout    = buf_dout;
						buf_din = in2;
					end
					else
					begin
						//
						// latter half step; butterfly is valid
						//
						in1        = buf_dout;
						//v_c[ RE ]  = quant_pkg::DEQUANT( prod_wr_i2r ) - quant_pkg::DEQUANT( prod_wi_i2i );
						//v_c[ IM ]  = quant_pkg::DEQUANT( prod_wr_i2i ) + quant_pkg::DEQUANT( prod_wi_i2r );
						v_c [ RE ] = prod_wr_i2r - prod_wi_i2i;
						v_c [ IM ] = prod_wr_i2i + prod_wi_i2r;

						out1[ RE ] = in1[ RE ] + v_c[ RE ];
						out1[ IM ] = in1[ IM ] + v_c[ IM ];
						out2[ RE ] = in1[ RE ] - v_c[ RE ];
						out2[ IM ] = in1[ IM ] - v_c[ IM ];
						// output newly computed butterfly's out1
						dout    = out1;
						buf_din = out2;
						/*
 						printtime();
						$display( "stage %0d, sampl_idx %0d, buf_rd_addr %0d", STAGE, sampl_idx, buf_rd_addr  );
						$display( "\tw = %08h + %08hj", w[ RE ], w[ IM ] );
						$display( "\tin1 = %08h + %08hj, in2 = %08h + %08hj", in1[ RE ], in1[ IM ], in2[ RE ], in2[ IM ] );
						$display( "\tout1 = %08h + %08hj, out2 = %08h + %08hj", out1[ RE ], out1[ IM ], out2[ RE ], out2[ IM ] );
						$display( "" );
						*/
					end

					buf_wr_en = 1'b1;
					out_wr_en = out_valid? 1'b1: 1'b0;

					if ( out_wr_en )
					begin
						//$display( "stage %0d outputting data %08h+%08hj", STAGE, out1[ RE ], out1[ IM ] );
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

			sampl_idx <= 'h0;

			in2[ RE ] <= 'sh0;
			in2[ IM ] <= 'sh0;
			v[ RE ] <= 'sh0;
			v[ IM ] <= 'sh0;

			prod_wr_i2r <= 'sh0;
			prod_wi_i2i <= 'sh0;
			prod_wr_i2i <= 'sh0;
			prod_wi_i2r <= 'sh0;
		end
		else
		begin
			fsm_state <= fsm_state_c;

			sampl_idx <= sampl_idx_c;

			in2[ RE ] <= in2_c[ RE ];
			in2[ IM ] <= in2_c[ IM ];
			v[ RE ] <= v_c[ RE ];
			v[ IM ] <= v_c[ IM ];

			prod_wr_i2r <= prod_wr_i2r_c;
			prod_wi_i2i <= prod_wi_i2i_c;
			prod_wr_i2i <= prod_wr_i2i_c;
			prod_wi_i2r <= prod_wi_i2r_c;
		end
	end

endmodule: fft_stage

