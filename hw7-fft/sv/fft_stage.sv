
import globals_pkg::printtime;
import quant_pkg::DEQUANT;

module fft_stage #(
	parameter int DWIDTH = 32,
	parameter int N = 1024,
	parameter int STAGE = 8
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
	localparam int
		REAL = 0, IMAG = 1;

	/*
	 * Use 0-based stage index
	 * STEP = offset between two samples in the same position in adjacent
	 * butterfly groups
	 * STAGE 0: [ in1[0] in2[0] ] [ in1[0] ... STEP = 2
	 * STAGE 1: [ in1[0] in1[1] in2[0] in2[1] ] [ in1[0] ... STEP = 4
	 */ 
	localparam int STEP = 2 << STAGE;
	localparam int HALF_STEP = STEP / 2;
	// Sample index within a frame
	localparam int SAMPLE_ID_WIDTH = $clog2( N );
	// in1/in2 combined delay buffer and twiddle ROM addr width = log( half step )
	localparam int MEM_ADDR_WIDTH = ( STAGE===0 ) ? 1 : STAGE;
	// Position of the bit in a sample idx that is 0 for in1 samples and 1 for
	// in2 samples
	localparam int IN2_FLAGBIT_POS = STAGE;

	typedef enum logic [ 5:0 ]
	{
		S_INIT,
		S_FETCH,
		S_MUL, S_DQ, S_ADD,
		S_OUT
	} fsm_state_t;
	fsm_state_t fsm_state_r, fsm_state_next;


	logic [ SAMPLE_ID_WIDTH:0 ] sample_id_r, sample_id_next;
	/* 
 	 * When the incoming sample is a in1, we ignore the butterfly 
 	 * and output the previous butterfly's out2 from buffer;
 	 * but when we're in step 0, there is no prev butterfly and our
 	 * module output is invalid for both in1 or in2 samples )
 	 */
	logic is_in2;

	/*
	 * Track whether the frame has progressed to the in2 samples of butterfly
	 * group 0 ( meaning we can begin outputting valid results )
	 */
	logic out_valid, out_valid_r;

	/* Butterfly and buffer signals */
	// twiddle factor index ( unique to each sample within a half-step )
	logic [ MEM_ADDR_WIDTH-1:0 ] w_rd_addr;
	logic w_rd_en;
	logic signed [ 0:1 ] [ DWIDTH-1:0 ] w_dout;

	logic [ MEM_ADDR_WIDTH-1:0 ] dly_buf_addr;
	logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		dly_buf_din, dly_buf_dout;
	logic dly_buf_wr_en, dly_buf_rd_en;

	logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		in1, in1_r,
		in2,
		w,
		v,   v_r,
		out1, out1_r,
		out2, out2_r;


	// clear path for multipliers ( no mux on input/output )
	logic signed [ 0:1 ] [ DWIDTH-1:0 ]
		mul_in2_r, mul_w_r;
	logic signed [ DWIDTH-1:0 ]
		mul_p1_r, mul_p2_r, mul_p3_r, mul_p4_r;

	// dequantize intermediate products
	logic signed [ DWIDTH-1:0 ]
		dq_p1, dq_p1_r,
		dq_p2, dq_p2_r,
		dq_p3, dq_p3_r,
		dq_p4, dq_p4_r;

	bram #(
		.DWIDTH( 2 * DWIDTH ),
		.ADDR_WIDTH( MEM_ADDR_WIDTH )
 	) dly_buf (
		.clk  ( clk ),
		.wr_addr( dly_buf_addr ),
		.rd_addr( dly_buf_addr ),
		.wr_en( dly_buf_wr_en ),
		.rd_en( dly_buf_rd_en ),
 		.din ( dly_buf_din ),
 		.dout( dly_buf_dout )
 	); 

	/*
	shiftreg #(
		.WIDTH( HALF_STEP ),
		.DWIDTH( 2 * DWIDTH )
	) dly_buf (
		.clk  ( clk ),
		.sh_en  ( dly_buf_wr_en ),
		.din    ( dly_buf_din ),
		.dout   ( dly_buf_dout )
	);
	*/ 

	stage_twd_rom
	#(
		.STAGE( STAGE ),
		.ADDR_WIDTH( MEM_ADDR_WIDTH )
	) w_rom (
		.clk( clk ),
		.rd_addr( w_rd_addr ),
		.rd_en( w_rd_en ),
		.dout( w_dout )
	);

	/*
 	 * When sample is in1, read back buffered out2 and send it downstream,
 	 * buffer in1
 	 * When sample is in2, read back buffered in1, run butterfly, overwrite
 	 * in1 with out2 at same half-step addr in buffer
	 */


	always_ff @( posedge clk )
	begin
		if ( rst )
		begin
			fsm_state_r <= S_INIT;
			sample_id_r <= 'h0;

			out_valid_r <= 1'b0;
		end
		else
		begin
			fsm_state_r <= fsm_state_next;
			sample_id_r <= sample_id_next;

			out_valid_r <= out_valid;
		end

		case ( fsm_state_r )
			S_FETCH:
			begin
				if( in_rd_en )
				begin
					if ( !is_in2 )
					begin
						in1_r[ 0:1 ] <= din[ 0:1 ];
					end
				end
			end
			S_DQ:
			begin
				dq_p1_r <= dq_p1;
				dq_p2_r <= dq_p2;
				dq_p3_r <= dq_p3;
				dq_p4_r <= dq_p4;
	
				v_r[ 0:1 ] <= v[ 0:1 ];

				if ( !is_in2 )
				begin
					out2_r[ 0:1 ] <= dly_buf_dout[ 0:1 ];
				end
				else
				begin
					in1_r[ 0:1 ] <= dly_buf_dout[ 0:1 ];
				end
			end
			S_ADD:
			begin
				if ( is_in2 )
				begin
					out1_r[ 0:1 ] <= out1[ 0:1 ];
					out2_r[ 0:1 ] <= out2[ 0:1 ];
				end
			end
			default:
			begin
			end

		endcase

	end

	always_ff @( posedge clk )
	begin: mul_reg
		if ( fsm_state_r === S_FETCH )
		begin
			mul_in2_r[ 0:1 ] <= in2[ 0:1 ];
			mul_w_r  [ 0:1 ] <= w  [ 0:1 ];
		end

		if ( fsm_state_r === S_MUL )
		begin
			mul_p1_r <= mul_in2_r[ REAL ] * mul_w_r[ REAL ];
			mul_p2_r <= mul_in2_r[ IMAG ] * mul_w_r[ IMAG ];
			mul_p3_r <= mul_in2_r[ REAL ] * mul_w_r[ IMAG ];
			mul_p4_r <= mul_in2_r[ IMAG ] * mul_w_r[ REAL ];
		end
	end: mul_reg

	generate
	if ( STAGE===0 )
	begin
		// only a single twiddle and a single delay buf elem
		assign w_rd_addr = 'h0;
		assign dly_buf_addr = 'h0;
	end
	else
	begin
		/*
		 * Used in S_INIT and S_OUT
		 * In S_INIT, sample_id_next == sample_id_r
		 */
		assign w_rd_addr = sample_id_next[ MEM_ADDR_WIDTH-1:0 ];
		/*
		 * Used in S_MUL ( read out2/in1 ) and S_OUT ( write in1/out2 )
		 */
		assign dly_buf_addr = sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
	end
	endgenerate

	always_comb
	begin
		fsm_state_next = fsm_state_r;

		sample_id_next = sample_id_r;

		in_rd_en = 1'b0;

		dly_buf_din[ 0:1 ] = '{ default: 'shx };
		dly_buf_rd_en = 1'b0;
		dly_buf_wr_en = 1'b0;

		w_rd_en = 1'b0;

		is_in2 = ( 1'b1===sample_id_r[ IN2_FLAGBIT_POS ] );

		in1[ 0:1 ] = '{ default: 'shx };
		in2[ 0:1 ] = '{ default: 'shx };

		dq_p1 = '{ default: 'shx };
		dq_p2 = '{ default: 'shx };
		dq_p3 = '{ default: 'shx };
		dq_p4 = '{ default: 'shx };

		v  [ 0:1 ] = '{ default: 'shx };

		out1[ 0:1 ] = '{ default: 'shx };
		out2[ 0:1 ] = '{ default: 'shx };

		out_valid = out_valid_r;

		out_wr_en = 1'b0;
		dout[ 0:1 ] = '{ default: 'sh0 };

		case ( fsm_state_r )
			S_INIT:
			begin
				// twiddle addr asserted
				w_rd_en = 1'b1;

				fsm_state_next = S_FETCH;
			end

			S_FETCH:
			begin
				/*
				 * in2 path
				 * If we stay in this state waiting for !in_empty,
				 * since w_rd_en is only 1 in S_INIT, w_dout won't change
				 */
				w[ 0:1 ] = w_dout[ 0:1 ];

				if ( !in_empty )
				begin
					if ( !is_in2 )
					begin
						// in1 path
						in1[ 0:1 ] = din[ 0:1 ];
					end
					else
					begin
						// in2 path
						in2[ 0:1 ] = din[ 0:1 ];
					end
					in_rd_en = 1'b1;
					fsm_state_next = S_MUL;
				end
			end

			S_MUL:
			begin
				// both paths: assert read addr
				dly_buf_rd_en = 1'b1;

				fsm_state_next = S_DQ;
			end

			S_DQ:
			begin

				if ( !is_in2 )
				begin
					// in1 path: decode out2
					out2[ 0:1 ] = dly_buf_dout[ 0:1 ];
				end
				else
				begin
					// in2 path: decode in1 and compute v
					in1[ 0:1 ] = dly_buf_dout[ 0:1 ];

					dq_p1 = DEQUANT( mul_p1_r );
					dq_p2 = DEQUANT( mul_p2_r );
					dq_p3 = DEQUANT( mul_p3_r );
					dq_p4 = DEQUANT( mul_p4_r );

					v[ REAL ] = dq_p1 - dq_p2;
					v[ IMAG ] = dq_p3 + dq_p4;
				end
				fsm_state_next = S_ADD;
			end

			S_ADD:
			begin
				if ( is_in2 )
				begin
					// in2 path: compute outputs
					out1[ REAL ] = in1_r[ REAL ] + v_r[ REAL ];
					out1[ IMAG ] = in1_r[ IMAG ] + v_r[ IMAG ];

					out2[ REAL ] = in1_r[ REAL ] - v_r[ REAL ];
					out2[ IMAG ] = in1_r[ IMAG ] - v_r[ IMAG ];
				end

				fsm_state_next = S_OUT;
			end

			S_OUT:
			begin
				if ( !out_full )
				begin
					if ( !is_in2 )
					begin
						// in1 path
						// output prev butterfly's buffered out2, store in1
						dout[ 0:1 ] = out2_r[ 0:1 ];

						dly_buf_din[ 0:1 ] = in1_r[ 0:1 ];
					end
					else
					begin
						// in2 path
						// output newly computed butterfly's out1, store out2
						dout[ 0:1 ] = out1_r[ 0:1 ];

						dly_buf_din[ 0:1 ] = out2_r[ 0:1 ];
					end
					dly_buf_wr_en = 1'b1;	

					/*
					 * When the first in2 sample is encountered, pull
					 * out_valid high, then clock it and allow to remain high
					 */
					out_valid = out_valid_r || sample_id_r[ IN2_FLAGBIT_POS ];
					out_wr_en = 1'( out_valid );

					sample_id_next = sample_id_r + 1'h1;

					/*
					* Since we don't return to S_INIT, we read-ahead w in this
					* state using incremented sample_id_next
					*/
					w_rd_en   = 1'b1;
					fsm_state_next = S_FETCH;
				end

			end

			default:
			begin
				fsm_state_next = S_INIT;
				sample_id_next = 'h0;
				out_valid = 1'b0;
			end

		endcase

	end

endmodule: fft_stage

