
module fft_stage #(
	parameter int STAGE = 2,
	parameter int N = 32,
	parameter int DWIDTH = 32,

	parameter logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		STAGE_TWDLS [ 0:(1<<(STAGE-1))-1 ]
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
		S_GET, S_BF_MUL_WI, S_BF_MUL_WR,
		S_BF_V, S_BF_OUT
	} fsm_state_t;
	fsm_state_t fsm_state, fsm_state_c;

	/* Sample idx = { step idx, lower step flag, buf sample addr } */ 
	logic [ LOG2_N:0 ] idx, idx_c;
	/* Step idx - has an extra high bit to accommodate final stage, 
	 * which has all samples within a single step but step idx couldn't possibly 
	 * be 0-bit wide. Also, it needs to enter a higher "ghost step" to flush the
	 * pipeline.
	 */
	logic [ LOG2_N-STAGE:0 ] step_idx;
	/* Sample belongs in upper or lower half of step, in terms of idx? 
 	 * ( when the incoming sample is in the lower half of step 0,
 	 * the butterfly output is invalid ) */
	logic is_lower_step;
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
		wr_x_i2r, wr_x_i2r_c,
		wi_x_i2i, wi_x_i2i_c,
		wr_x_i2i, wr_x_i2i_c,
		wi_x_i2r, wi_x_i2r_c;

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

	//assign { step_idx, is_lower_step, buf_rd_addr }
	//	= { idx[ LOG2_N:STAGE ], idx[ STAGE-1 ], idx[ STAGE-2:0 ] };
	assign step_idx      = idx[ LOG2_N:STAGE ];
	assign is_lower_step = idx[ STAGE-1 ];
	assign buf_rd_addr   = idx[ STAGE-2:0 ];

	assign out_valid = !( step_idx===0 && is_lower_step );
	/*
 	 * In lower step, read back buffered out2 and send it downstream,
 	 * buffer in1
 	 * In higher step, read back buffered in1, run butterfly, overwrite
 	 * in1 with out2 at same half-step addr in buffer
	 */
	assign buf_wr_addr = buf_rd_addr;

	always_comb
	begin
		fsm_state_c = fsm_state;

		dout[ RE ] = 'shX;
		dout[ IM ] = 'shX;
		out_wr_en = 1'b0;

		buf_din[ RE ] = 'shX;
		buf_din[ IM ] = 'shX;
		buf_wr_en = 1'b0;

		idx_c = idx;

		in1 = buf_dout;

		in2_c[ RE ] = in2[ RE ];
		in2_c[ IM ] = in2[ IM ];
		v_c[ RE ] = v[ RE ];
		v_c[ IM ] = v[ IM ];

		wr_x_i2r_c = wr_x_i2r;
		wi_x_i2i_c = wi_x_i2i;
		wr_x_i2i_c = wr_x_i2i;
		wi_x_i2r_c = wi_x_i2r;

		/* only significant in S_BF_OUT with !is_lower_step */
		out1[ RE ] = in1[ RE ] + v[ RE ];
		out1[ IM ] = in1[ IM ] + v[ IM ];
		out2[ RE ] = in1[ RE ] - v[ RE ];
		out2[ IM ] = in1[ IM ] - v[ IM ];

		case ( fsm_state )
			S_GET:
			begin
				if ( !in_empty )
				begin
					in_rd_en = 1'b1;
					in2_c = din;
					fsm_state_c = is_lower_step
						? S_BF_MUL_WI
						: S_BF_OUT;
				end
			end

			S_BF_MUL_WI:
			begin
				wi_x_i2r_c = w[ IM ] * in2[ RE ];
				wi_x_i2i_c = w[ IM ] * in2[ IM ];
				fsm_state_c = S_BF_MUL_WR;
			end

			S_BF_MUL_WR:
			begin
				wi_x_i2r_c = quant_pkg::DEQUANT( wi_x_i2r );
				wi_x_i2i_c = quant_pkg::DEQUANT( wi_x_i2i );

				wr_x_i2r_c = w[ RE ] * in2[ RE ];
				wr_x_i2i_c = w[ RE ] * in2[ IM ];

				fsm_state_c = S_BF_V;
			end

			S_BF_V:
			begin
				v_c[ RE ] = quant_pkg::DEQUANT( wr_x_i2r ) - wi_x_i2i;
				v_c[ IM ] = quant_pkg::DEQUANT( wr_x_i2i ) + wi_x_i2r;
				fsm_state_c = S_BF_OUT;
			end

			S_BF_OUT:
			begin
				if ( !out_full )
				begin

					if ( is_lower_step )
					begin
						dout = buf_dout;
						buf_din = in2;
					end
					else
					begin
						dout = out1;
						buf_din = out2;
					end
					buf_wr_en = 1'b1;
					out_wr_en = out_valid? 1'b1: 1'b0;

					idx_c = idx + 1'h1;
					fsm_state_c = S_GET;
				end

			end

		endcase

	end

	always_ff @ ( posedge clk )
	begin: rd_twdl
		w <= STAGE_TWDLS[ buf_rd_addr ];
	end: rd_twdl

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			fsm_state <= S_GET;

			idx <= 'h0;

			in2[ RE ] <= 'sh0;
			in2[ IM ] <= 'sh0;
			v[ RE ] <= 'sh0;
			v[ IM ] <= 'sh0;

			wr_x_i2r <= 'sh0;
			wi_x_i2i <= 'sh0;
			wr_x_i2i <= 'sh0;
			wi_x_i2r <= 'sh0;
		end
		else
		begin
			fsm_state <= fsm_state_c;

			idx <= idx_c;

			in2[ RE ] <= in2_c[ RE ];
			in2[ IM ] <= in2_c[ IM ];
			v[ RE ] <= v_c[ RE ];
			v[ IM ] <= v_c[ IM ];

			wr_x_i2r <= wr_x_i2r_c;
			wi_x_i2i <= wi_x_i2i_c;
			wr_x_i2i <= wr_x_i2i_c;
			wi_x_i2r <= wi_x_i2r_c;
		end
	end

endmodule: fft_stage

