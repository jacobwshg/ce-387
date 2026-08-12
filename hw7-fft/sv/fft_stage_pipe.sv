
import globals_pkg :: N;
import globals_pkg :: DWIDTH;
import globals_pkg :: printtime;
import twdls_pkg :: TWDLS;

module fft_stage #(
	parameter int STAGE = 3,
	parameter int N = globals_pkg::N,
	parameter int DWIDTH = globals_pkg::DWIDTH
)
(
	input  logic clk,
	input  logic rst,

	input  logic signed [ DWIDTH-1:0 ] din_real, din_imag,
	input  logic in_empty,
	output logic in_rd_en,

	input  logic out_full,
	output logic signed [ DWIDTH-1:0 ] dout_real, dout_imag,
	output logic out_wr_en
);
	import quant_pkg::DEQUANT;

	/* 
	 * width of sample IDs within a frame
	 * add an overflow bit above MSB to facilitate pipeline flush
	 * 8-point:  3+1
	 * 16-point: 4+1
	 */
	localparam int SAMPLE_ID_WIDTH = $clog2( N ) + 1;
	/* 
	 * distance ( sample ID diff ) between a butterfly's sample pair
	 * stage 0:1; stage 1:2; stage 2:4; stage 3:8
	 */
	localparam int STEP = 2 ** STAGE; 
	/* 
 	 * addr width of twdl table / in1 buf / out2 buf
	 * stage 0:1 ( 1 elem; addr 0 only )
	 * stage 1:1 ( 2 elems )
	 * stage 2:2 ( 4 elems )
	 * stage 3:3 ( 8 elems )
	 */
	localparam int MEM_ADDR_WIDTH = ( STAGE===0 ) ? ( STAGE+1 ) : STAGE;
	localparam int IN2_FLAGBIT_POS = ( STAGE===0 ) ? 0 : MEM_ADDR_WIDTH;
	localparam int STEPID_WIDTH = SAMPLE_ID_WIDTH - MEM_ADDR_WIDTH - ( ( 0===STAGE ) ? 0 : 1 );

	// # stages in mul_cmplx retimed shift regs ( excluding input regs )
	localparam int MUL_STAGES = 5;

	logic pipe_wr_en;

	// butterfly operands memory
	logic bfly_in1_wr_en, bfly_out2_wr_en;
	logic [ MEM_ADDR_WIDTH-1:0 ]
		bfly_w_rd_addr, // assume clocked by ROM controller
		bfly_in1_wr_addr, bfly_in1_rd_addr,
		bfly_out2_wr_addr, bfly_out2_rd_addr;
	logic signed [ DWIDTH-1:0 ]
		bfly_w_rd_real, bfly_w_rd_imag,
		bfly_in1_wr_real, bfly_in1_wr_imag, bfly_in1_rd_real, bfly_in1_rd_imag,
		bfly_out2_wr_real, bfly_out2_wr_imag, bfly_out2_rd_real, bfly_out2_rd_imag;

	// fetch stage
	logic [ SAMPLE_ID_WIDTH-1:0 ]
		fetch_sample_id_r,      // exposed to mul
		fetch_next_sample_id_r, fetch_next_sample_id; // stage-internal use
	logic signed [ DWIDTH-1:0 ]
		fetch_din_real_r, fetch_din_imag_r;
	logic fetch_valid_r;
	logic [ MEM_ADDR_WIDTH-1:0 ] fetch_mem_addr; // send to in1 mem

	// butterfly in2 * twdl multiply stage
	// sideband
	logic [ SAMPLE_ID_WIDTH-1:0 ] mul_sample_id_r [ 0:MUL_STAGES ];
	logic mul_valid_r [ 0:MUL_STAGES ];
	// clocked into mul_cmplx input regs
	logic signed [ DWIDTH-1:0 ]
		mul_in2_real, mul_in2_imag,
		mul_w_real, mul_w_imag;
	// mul_cmplx outputs
	logic signed [ DWIDTH-1:0 ]
		mul_p1, mul_p2, mul_p3;

	// dequantize stage ( in2 )
	logic signed [ DWIDTH-1:0 ]
		dq_p1_r, dq_p2_r, dq_p3_r,
		dq_p1,   dq_p2,   dq_p3;
	logic [ SAMPLE_ID_WIDTH-1:0 ] dq_sample_id_r;
	logic dq_valid_r;
	logic [ MEM_ADDR_WIDTH-1:0 ] dq_mem_addr; // send to in1 buf

	// add1 stage ( derive v_real and v_imag from p1, p2, p3; clock in1 )
	logic signed [ DWIDTH-1:0 ] add1_v_real_r, add1_v_imag_r, add1_in1_real_r, add1_in1_imag_r;
	logic [ SAMPLE_ID_WIDTH-1:0 ] add1_sample_id_r;
	logic add1_valid_r;
	logic signed [ DWIDTH-1:0 ] add1_v_real, add1_v_imag, add1_in1_real, add1_in1_imag;
	logic [ MEM_ADDR_WIDTH-1:0 ] add1_mem_addr;

	// add2 stage ( derive out1 and out2 from v and in1 )
	logic signed [ DWIDTH-1:0 ] add2_out1_real_r, add2_out1_imag_r, add2_out2_real_r, add2_out2_imag_r;	
	logic [ SAMPLE_ID_WIDTH-1:0 ] add2_sample_id_r;
	logic add2_valid_r;
	logic signed [ DWIDTH-1:0 ] add2_out1_real, add2_out1_imag, add2_out2_real, add2_out2_imag;

	// output stage
	logic out_valid_r, out_valid;
	logic [ MEM_ADDR_WIDTH-1:0 ] out_mem_addr;

	stage_twd_rom #(
		.STAGE( STAGE ),
		.ADDR_WIDTH( MEM_ADDR_WIDTH ),
		.STEP( STEP )
	) bfly_ws (
		.clk( clk ),
		.rd_addr( bfly_w_rd_addr ),
		.dout( { bfly_w_rd_real, bfly_w_rd_imag } )
	);

	bram #(
		.BRAM_ADDR_WIDTH( MEM_ADDR_WIDTH ),
		.BRAM_DATA_WIDTH( DWIDTH * 2 )
	) bfly_in1_buf (
		.clock( clk ),
		.rd_addr( bfly_in1_rd_addr ), .wr_addr( bfly_in1_wr_addr ),
		.wr_en( bfly_in1_wr_en ),
		.din( { $unsigned( bfly_in1_wr_real ), $unsigned( bfly_in1_wr_imag ) } ),
		.dout( { bfly_in1_rd_real, bfly_in1_rd_imag } )
	);

	bram #(
		.BRAM_ADDR_WIDTH( MEM_ADDR_WIDTH ),
		.BRAM_DATA_WIDTH( DWIDTH * 2 )
	) bfly_out2_buf (
		.clock( clk ),
		.rd_addr( bfly_out2_rd_addr ), .wr_addr( bfly_out2_wr_addr ),
		.wr_en( bfly_out2_wr_en ),
		.din( { $unsigned( bfly_out2_wr_real ), $unsigned( bfly_out2_wr_imag ) } ),
		.dout( { bfly_out2_rd_real, bfly_out2_rd_imag } )
	);

	mul_cmplx #(
		.STAGES( MUL_STAGES ),
		.DWIDTH( DWIDTH )
	) mul_cmplx_pipe (
		.clk( clk ), .rst( rst ), .wr_en( pipe_wr_en ),
		.a( mul_w_real ), .  b( mul_w_imag ), 
		.c( mul_in2_real ), .d( mul_in2_imag ), 
		.p1( mul_p1 ), .p2( mul_p2 ), .p3( mul_p3 )
	);

	assign pipe_wr_en = !out_full && !in_empty;
	assign in_rd_en = pipe_wr_en;

	/*
	 * Let in2 sample i be clocked into fetch_din_*_r 
	 * and ID i be clocked into w buf's rd_addr_r on the same clock edge c,
	 * so that sample i and the matching w output can be clocked into
	 * mul_cmplx's input regs on clock edge c+1.
	 * The ID signal that provides the matching i is fetch_next_sample_id_r;
	 * fetch_sample_id_r may be i-1 and fetch_next_sample_id may be i+1
	 *
	 */ 
	generate
		if ( STAGE === 0 )
		begin
			assign fetch_mem_addr = 'h0;
			assign bfly_w_rd_addr = 'h0;
		end
		else
		begin
			assign fetch_mem_addr = fetch_next_sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
			assign bfly_w_rd_addr = fetch_mem_addr;
		end
	endgenerate
	assign fetch_next_sample_id = fetch_next_sample_id_r + 1'( in_rd_en );

	/*
	 * in1 is clocked in fetch_din_*_r before buffering, so as to avoid 
	 * traversing input FIFO and in1 buf's addr trees in the same cycle.
	 * The ID that is in sync with a given in1 clocked in fetch_din_*_r is
	 * the ID clocked in fetch_sample_id_r
	 */
	generate
		if ( STAGE === 0 )
			assign bfly_in1_wr_addr = 'h0;
		else
			assign bfly_in1_wr_addr = fetch_sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
	endgenerate	
	assign bfly_in1_wr_en = fetch_valid_r && !fetch_sample_id_r[ IN2_FLAGBIT_POS ];

	/*
	 * mul_cmplx input reg inputs
	 */
	assign mul_w_real = bfly_w_rd_real;
	assign mul_w_imag = bfly_w_rd_imag;
	assign mul_in2_real = fetch_din_real_r;
	assign mul_in2_imag = fetch_din_imag_r;

	/*
	 * On clk edge c, partial products are clocked into mul_cmplx final 
	 * output regs ( internally p*_r[ STAGE-1 ], exposed as mul_p* ), 
	 * and the sample's matching ID is clocked into mul_sample_id_r[
	 * MUL_STAGES ];
	 *
	 * On clk edge c+1, let partial products after dequantization be clocked 
	 * into dq_p*_r, and in1 mem addr derived from prev edge's 
	 * mul_sample_id_r[ MUL_STAGES ] be clocked into in1 buf's rd_addr_r;
	 *
	 * On clk edge c+2, the partial products' add/sub results are clocked
	 * into add1_v_*_r, and in1 buf outputs are clocked into add1_in1_*_r,
	 * synced and ready for add2.
	 *
	 */
	assign dq_p1 = quant_pkg::DEQUANT( mul_p1 );
	assign dq_p2 = quant_pkg::DEQUANT( mul_p2 );
	assign dq_p3 = quant_pkg::DEQUANT( mul_p3 );
	generate
		if ( STAGE === 0 )
		begin
			assign dq_mem_addr = 'h0;
			assign bfly_in1_rd_addr = 'h0;
		end
		else
		begin
			assign dq_mem_addr = mul_sample_id_r[ MUL_STAGES ][ MEM_ADDR_WIDTH-1:0 ];
			assign bfly_in1_rd_addr = dq_mem_addr;
		end
	endgenerate

	/*
	 * For in1 samples, the out2 clocked between add2 and out should not be
	 * "in1 - v" ( which is only valid for in2 samples ), but rather out2 buf
	 * output. 
	 * Thus the out2 buf addr should be clocked between add1 and add2, which
	 * requires it be derived from dq_sample_id_r and be asserted over the
	 * add1 cycle.
	 *
	 * For STAGE >= 1, when an out2 sample is in "out" stage, the incoming in1 
	 * that outputs this out2 can only be as deep as add1. During the next
	 * cycle, the out2 sample has written to out2 buf and retired, and the in1
	 * can decode from the same address. But for STAGE = 0, when the out2 is in 
	 * "out", the in1 that uses it is already in add1; the out2 read by
	 * this in1 is stale, and the true out2 must be forwarded from
	 * add2_out2_*_r.
	 *
	 */
	assign add1_v_real = dq_p2_r - dq_p1_r;
	assign add1_v_imag = dq_p2_r + dq_p3_r;
	assign add1_in1_real = bfly_in1_rd_real;
	assign add1_in1_imag = bfly_in1_rd_imag;
	generate
		if ( STAGE === 0 )
		begin
			assign add1_mem_addr = 'h0;
			assign bfly_out2_rd_addr = 'h0;
		end
		else
		begin
			assign add1_mem_addr = dq_sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
			assign bfly_out2_rd_addr = add1_mem_addr;
		end
	endgenerate

	assign add2_out1_real = add1_in1_real_r + add1_v_real_r;
	assign add2_out1_imag = add1_in1_imag_r + add1_v_imag_r;
	generate
		if ( STAGE === 0 )
		always_comb
		begin
			if ( add1_sample_id_r[ IN2_FLAGBIT_POS ] )
			begin
				add2_out2_real = add1_in1_real_r - add1_v_real_r;
				add2_out2_imag = add1_in1_imag_r - add1_v_imag_r;
			end
			else if ( add2_valid_r && ( add2_sample_id_r === add1_sample_id_r + 1'h1 ) )
			begin // forward
				add2_out2_real = add2_out2_real_r;
				add2_out2_imag = add2_out2_imag_r;
			end
			else
			begin
				add2_out2_real = bfly_out2_rd_real;
				add2_out2_imag = bfly_out2_rd_imag;
			end
		end
		else
		always_comb
		begin
			if ( add1_sample_id_r[ IN2_FLAGBIT_POS ] )
			begin
				add2_out2_real = add1_in1_real_r - add1_v_real_r;
				add2_out2_imag = add1_in1_imag_r - add1_v_imag_r;
			end
			else
			begin
				add2_out2_real = bfly_out2_rd_real;
				add2_out2_imag = bfly_out2_rd_imag;
			end
		end
	endgenerate

	// TODO messy
	assign out_valid = out_valid_r || ( add2_valid_r && add2_sample_id_r[ IN2_FLAGBIT_POS ] );
	assign out_wr_en = out_valid;
	generate
		if ( STAGE === 0 )
		begin
			assign out_mem_addr = 'h0;
			assign bfly_out2_wr_addr = 'h0;
		end
		else
		begin
			assign out_mem_addr = add2_sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
			assign bfly_out2_wr_addr = out_mem_addr;
		end
	endgenerate
	assign bfly_out2_wr_en = add2_valid_r && add2_sample_id_r[ IN2_FLAGBIT_POS ];

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			fetch_next_sample_id_r <= 'h0;
			fetch_sample_id_r <= 'h0;
			///{ fetch_din_real_r, fetch_din_imag_r } <= '{ default: 'sh0 };
			///{ fetch_w_real_r,   fetch_w_imag_r }   <= '{ default: 'sh0 };
			fetch_valid_r <= 1'b0;
			mul_valid_r[ 0:MUL_STAGES ] <= '{ default: 1'b0 };
			dq_valid_r <= 1'b0;
			add1_valid_r <= 1'b0;
			add2_valid_r <= 1'b0;

		end
		else if ( pipe_wr_en )
		begin
			fetch_sample_id_r       <= fetch_next_sample_id_r;
			fetch_next_sample_id_r  <= fetch_next_sample_id;
			{ fetch_din_real_r, fetch_din_imag_r } <= { din_real, din_imag };

			globals_pkg::printtime();
			$strobe( "fetch_din_real : %h + %hj", fetch_din_real_r, fetch_din_imag_r );

			fetch_valid_r <= in_rd_en;

			mul_sample_id_r[ 0 ] <= fetch_sample_id_r;
			mul_sample_id_r[ 1:MUL_STAGES ] <= mul_sample_id_r[ 0:MUL_STAGES-1 ];
			mul_valid_r[ 0 ] <= fetch_valid_r;
			mul_valid_r[ 1:MUL_STAGES ] <= mul_valid_r[ 0:MUL_STAGES-1 ];

			dq_p1_r <= dq_p1;
			dq_p2_r <= dq_p2;
			dq_p3_r <= dq_p3;
			dq_sample_id_r <= mul_sample_id_r[ MUL_STAGES ];
			dq_valid_r <= mul_valid_r[ MUL_STAGES ];

			add1_v_real_r <= add1_v_real;
			add1_v_imag_r <= add1_v_imag;
			add1_in1_real_r <= add1_in1_real;
			add1_in1_imag_r <= add1_in1_imag;
			add1_sample_id_r <= dq_sample_id_r;
			add1_valid_r <= dq_valid_r;

			add2_out1_real_r <= add2_out1_real;
			add2_out1_imag_r <= add2_out1_imag;
			add2_out2_real_r <= add2_out2_real;
			add2_out2_imag_r <= add2_out2_imag;
			add2_sample_id_r <= add1_sample_id_r;
			add2_valid_r <= add1_valid_r;

			out_valid_r <= out_valid;
		end
	end

endmodule: fft_stage

