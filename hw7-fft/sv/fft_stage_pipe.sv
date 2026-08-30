
module fft_stage #(
	parameter int DWIDTH = 32,
	parameter int N = 16,
	parameter int STAGE = 2,

	// # stages in mul_cmplx retimed regs ( excluding input reg )
	parameter int MUL_STAGES = 2,

	parameter logic DBG = 1'b0
)
(
	input  logic clk,
	input  logic rst,

	input  logic in_empty,
	input  logic signed [ DWIDTH-1:0 ] din_real,
	input  logic signed [ DWIDTH-1:0 ] din_imag,
	output logic in_rd_en,

	input  logic out_full,
	output logic signed [ DWIDTH-1:0 ] dout_real,
	output logic signed [ DWIDTH-1:0 ] dout_imag,
	output logic out_wr_en
);
	import quant_pkg::DEQUANT;

	/* mul_cmplx sideband depth ( 1 for input regs ) */
	localparam int MUL_SBD_STAGES = 1 + MUL_STAGES;

	/* 
	 * width of sample IDs within a frame
	 * add an overflow bit above MSB to facilitate pipeline flush
	 * 8-point:  1+3
	 * 16-point: 1+4
	 */
	localparam int SAMPLE_ID_WIDTH = 1 + $clog2( N );
	/* 
 	 * addr width of twdl table / in1 buf / out2 buf
	 * stage 0:1 ( 1 elem; addr 0 only )
	 * stage 1:1 ( 2 elems )
	 * stage 2:2 ( 4 elems )
	 * stage 3:3 ( 8 elems )
	 */
	localparam int MEM_ADDR_WIDTH = ( STAGE===0 ) ? ( STAGE+1 ) : STAGE;
	localparam int IN2_FLAGBIT_POS = ( STAGE===0 ) ? 0 : MEM_ADDR_WIDTH;

	/* in1 can be buffered after FETCH and read back in ADD1 to avoid
	 * sidebanding. To make this possible, the buffer must be deeper than
	 * the middle section of the pipeline to avoid in1 across different
	 * strides overwriting the same address.
	 */
	localparam int IN1_SAFE_ADDR_WIDTH = $clog2( MUL_SBD_STAGES + 3 );
	localparam int IN1_MEM_ADDR_WIDTH =
		( MEM_ADDR_WIDTH>IN1_SAFE_ADDR_WIDTH ) ? MEM_ADDR_WIDTH : IN1_SAFE_ADDR_WIDTH;

	logic pipe_wr_en;

	/* butterfly operands memory */
	logic [ MEM_ADDR_WIDTH-1:0 ] bfly_w_rd_addr;
	logic signed [ DWIDTH-1:0 ]  bfly_w_rd_real, bfly_w_rd_imag;

	logic bfly_out2_wr_en;
	logic [ MEM_ADDR_WIDTH-1:0 ] bfly_out2_wr_addr;
	logic signed [ DWIDTH-1:0 ]  bfly_out2_wr_real, bfly_out2_wr_imag;
	logic [ MEM_ADDR_WIDTH-1:0 ] bfly_out2_rd_addr;
	logic signed [ DWIDTH-1:0 ]  bfly_out2_rd_real, bfly_out2_rd_imag;

	logic bfly_in1_wr_en;
	logic [ IN1_MEM_ADDR_WIDTH-1:0 ] bfly_in1_wr_addr;
	//logic [ MEM_ADDR_WIDTH-1:0 ] bfly_in1_wr_addr;
	logic signed [ DWIDTH-1:0 ]      bfly_in1_wr_real, bfly_in1_wr_imag;
	logic [ IN1_MEM_ADDR_WIDTH-1:0 ] bfly_in1_rd_addr;
	//logic [ MEM_ADDR_WIDTH-1:0 ] bfly_in1_rd_addr;
	logic signed [ DWIDTH-1:0 ]      bfly_in1_rd_real, bfly_in1_rd_imag;


	// fetch stage
	// sample ID exposed to mul
	logic [ SAMPLE_ID_WIDTH-1:0 ] fetch_sample_id_r;
	// sample ID tracked stage-internally
	logic [ SAMPLE_ID_WIDTH-1:0 ]  fetch_next_sample_id, fetch_next_sample_id_r;
	// clocked from input FIFO
	logic signed [ DWIDTH-1:0 ] fetch_din_real_r, fetch_din_imag_r; 
	logic fetch_valid_r;
	logic [ MEM_ADDR_WIDTH-1:0 ] fetch_mem_addr;

	// butterfly in2 * twdl multiply stage
	// sideband sample ID and valid flag; depth matches mul_cmplx
	// input reg + pipeline regs
	logic [ SAMPLE_ID_WIDTH-1:0 ] mul_sample_id_r [ 0:MUL_SBD_STAGES-1 ];
	logic mul_valid_r [ 0:MUL_SBD_STAGES-1 ]; 
	// clocked into mul_cmplx input reg
	logic signed [ DWIDTH-1:0 ] mul_in_a, mul_in_b, mul_in_c, mul_in_d;
	// driven by mul_cmplx final output reg
	logic signed [ DWIDTH-1:0 ] mul_out_p1, mul_out_p2, mul_out_p3; 

	// dequantize stage ( in2 )
	logic signed [ DWIDTH-1:0 ]
		dq_p1,   dq_p2,   dq_p3,
		dq_p1_r, dq_p2_r, dq_p3_r;
	logic [ SAMPLE_ID_WIDTH-1:0 ] dq_sample_id; 
	logic [ SAMPLE_ID_WIDTH-1:0 ] dq_sample_id_r;
	logic dq_valid_r;

	// add1 stage ( derive v_real and v_imag from p1, p2, p3; clock in1 )
	logic signed [ DWIDTH-1:0 ] add1_v_real, add1_v_imag, add1_in1_real, add1_in1_imag;
	logic [ MEM_ADDR_WIDTH-1:0 ] add1_mem_addr;
	logic signed [ DWIDTH-1:0 ] add1_v_real_r, add1_v_imag_r, add1_in1_real_r, add1_in1_imag_r;
	logic [ SAMPLE_ID_WIDTH-1:0 ] add1_sample_id_r;
	logic add1_valid_r;

	// add2 stage ( derive out1 and out2 from v and in1 )
	logic add2_is_in2;
	logic signed [ DWIDTH-1:0 ] add2_out1_real, add2_out1_imag, add2_out2_real, add2_out2_imag;
	logic signed [ DWIDTH-1:0 ] add2_out1_real_r, add2_out1_imag_r, add2_out2_real_r, add2_out2_imag_r;	
	logic [ SAMPLE_ID_WIDTH-1:0 ] add2_sample_id_r;
	logic add2_valid_r;


	// output stage
	logic [ MEM_ADDR_WIDTH-1:0 ] out_mem_addr;
	// out_valid(_r) indicates whether the sample is past the initial group of
	// in1 samples, which read garbage out2s from buf; the validity of the
	// sample itself is reflected by add2_valid_r.
	logic out_valid, out_valid_r;
	// prevent duplicate writes to output FIFO
	logic out_dup;
	logic [ SAMPLE_ID_WIDTH-1:0 ] out_prev_sample_id_r;
	logic out_prev_wr_en_r;

	stage_twd_rom #(
		.STAGE( STAGE ),
		.ADDR_WIDTH( MEM_ADDR_WIDTH )
	) bfly_ws (
		.clk( clk ),
		.rd_addr( bfly_w_rd_addr ),
		.rd_en( pipe_wr_en ),
		.dout( { bfly_w_rd_real, bfly_w_rd_imag } )
	);

	bram #(
		.DWIDTH( DWIDTH * 2 ),
		.ADDR_WIDTH( IN1_MEM_ADDR_WIDTH )
	) bfly_in1_buf (
		.clk( clk ),
		.wr_addr( bfly_in1_wr_addr ),
		.rd_addr( bfly_in1_rd_addr ),
		.wr_en( bfly_in1_wr_en ),
		.rd_en( pipe_wr_en ),
		.din( { $unsigned( bfly_in1_wr_real ), $unsigned( bfly_in1_wr_imag ) } ),
		.dout( { bfly_in1_rd_real, bfly_in1_rd_imag } )
	);

	bram #(
		.DWIDTH( DWIDTH * 2 ),
		.ADDR_WIDTH( MEM_ADDR_WIDTH )
	) bfly_out2_buf (
		.clk( clk ),
		.wr_addr( bfly_out2_wr_addr ),
		.rd_addr( bfly_out2_rd_addr ),
		.wr_en( bfly_out2_wr_en ),
		.rd_en( pipe_wr_en ), 
		.din( { $unsigned( bfly_out2_wr_real ), $unsigned( bfly_out2_wr_imag ) } ),
		.dout( { bfly_out2_rd_real, bfly_out2_rd_imag } )
	);

	mul_cmplx #(
		.STAGES( MUL_STAGES ),
		.DWIDTH( DWIDTH )
	) mul_cmplx_pipe (
		.clk( clk ), .rst( rst ), .wr_en( pipe_wr_en ),
		.a( mul_in_a ), .b( mul_in_b ), .c( mul_in_c ), .d( mul_in_d ), 
		.p1( mul_out_p1 ), .p2( mul_out_p2 ), .p3( mul_out_p3 )
	);

	assign pipe_wr_en = ( !out_full ) /*|| !add2_valid_r*/;
	assign in_rd_en = pipe_wr_en && !in_empty;

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
	assign bfly_in1_wr_real = fetch_din_real_r;
	assign bfly_in1_wr_imag = fetch_din_imag_r;
	generate
		if ( SAMPLE_ID_WIDTH < IN1_MEM_ADDR_WIDTH )
			assign bfly_in1_wr_addr = 'h0 | fetch_sample_id_r[ SAMPLE_ID_WIDTH-1:0 ];
		else
			assign bfly_in1_wr_addr = fetch_sample_id_r[ IN1_MEM_ADDR_WIDTH-1:0 ];
	endgenerate	
	assign bfly_in1_wr_en = fetch_valid_r && !fetch_sample_id_r[ IN2_FLAGBIT_POS ];

	/*
	 * mul_cmplx input reg inputs
	 */
	assign mul_in_c = bfly_w_rd_real;
	assign mul_in_d = bfly_w_rd_imag;
	assign mul_in_a = fetch_din_real_r;
	assign mul_in_b = fetch_din_imag_r;

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
	assign dq_p1 = quant_pkg::DEQUANT( mul_out_p1 );
	assign dq_p2 = quant_pkg::DEQUANT( mul_out_p2 );
	assign dq_p3 = quant_pkg::DEQUANT( mul_out_p3 );
	assign dq_sample_id = mul_sample_id_r[ MUL_SBD_STAGES-1 ];
	// We only care about bfly_in1_rd_addr when the sample in DQ is in2;
	// it differs from the matching in1 only by having the flag bit as
	// 1 instead of 0.
	generate
		if ( SAMPLE_ID_WIDTH < IN1_MEM_ADDR_WIDTH )
		always_comb
		begin
			bfly_in1_rd_addr = ( 'h0 | dq_sample_id[ SAMPLE_ID_WIDTH-1:0 ] );
			bfly_in1_rd_addr[ IN2_FLAGBIT_POS ] = 1'b0;
		end
		else
		always_comb
		begin
			bfly_in1_rd_addr = dq_sample_id[ IN1_MEM_ADDR_WIDTH-1:0 ];
			bfly_in1_rd_addr[ IN2_FLAGBIT_POS ] = 1'b0;
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
	 * For STAGE >= 1, when an out2 sample is in OUT stage, the incoming in1 
	 * that outputs this out2 can only be as deep as add1. During the next
	 * cycle, the out2 sample has written to out2 buf and retired, and the in1
	 * can decode from the same address. But for STAGE = 0, when the out2 is in 
	 * OUT, the in1 that uses it is already in ADD1; the out2 read by
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

	assign add2_is_in2 = add1_sample_id_r[ IN2_FLAGBIT_POS ];
	assign add2_out1_real = add1_in1_real_r + add1_v_real_r;
	assign add2_out1_imag = add1_in1_imag_r + add1_v_imag_r;
	generate
		if ( STAGE === 0 )
		always_comb
		begin
			if ( add2_is_in2 )
			begin
				add2_out2_real = add1_in1_real_r - add1_v_real_r;
				add2_out2_imag = add1_in1_imag_r - add1_v_imag_r;
			end
			else if (
				//add2_valid_r && 
				( ( add2_sample_id_r + 1'h1 ) === add1_sample_id_r )
			)
			begin
				/*
				 * FFT stage 0 forwarding case: the sample in ADD2 stage is in1,
				 * and the sample in OUT stage has an ID that is 1 less
				 * ( meaning it is the previous butterfly's in2 ), and it had
				 * buffered the previous out2 in add2_out2_*_r.
				 *
				 */
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
			add2_out2_real = bfly_out2_rd_real;
			add2_out2_imag = bfly_out2_rd_imag;

			if ( add2_is_in2 )
			begin
				add2_out2_real = add1_in1_real_r - add1_v_real_r;
				add2_out2_imag = add1_in1_imag_r - add1_v_imag_r;
			end
		end
	endgenerate

	assign dout_real = add2_sample_id_r[ IN2_FLAGBIT_POS ] ? add2_out1_real_r : add2_out2_real_r;
	assign dout_imag = add2_sample_id_r[ IN2_FLAGBIT_POS ] ? add2_out1_imag_r : add2_out2_imag_r;

	assign out_dup =
		( add2_sample_id_r===out_prev_sample_id_r ) && out_prev_wr_en_r;

	/*
	 * A tiny state machine: if prev samples are all in the initial group of
	 * in1, out_valid is first asserted when add2_sample_id_r's in2 flag bit
	 * turns high, indicating the earliest in2 sample. Then it is clocked into
	 * out_valid_r and stays high.
	 */
	assign out_valid = out_valid_r || ( add2_valid_r && add2_sample_id_r[ IN2_FLAGBIT_POS ] );
	assign out_wr_en = add2_valid_r && pipe_wr_en && out_valid && !out_dup;

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
	assign bfly_out2_wr_real = add2_out2_real_r;
	assign bfly_out2_wr_imag = add2_out2_imag_r;
	assign bfly_out2_wr_en = add2_valid_r && add2_sample_id_r[ IN2_FLAGBIT_POS ];

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			fetch_next_sample_id_r <= 'h0;
			fetch_sample_id_r <= 'h0;
			fetch_valid_r <= 1'b0;
			mul_valid_r[ 0:MUL_SBD_STAGES-1 ] <= '{ default: 1'b0 };
			dq_valid_r <= 1'b0;
			add1_valid_r <= 1'b0;
			add2_valid_r <= 1'b0;
			out_valid_r <= 1'b0;
			out_prev_wr_en_r <= 1'b0;
		end
		else if ( pipe_wr_en )
		begin
			fetch_sample_id_r       <= fetch_next_sample_id_r;
			fetch_next_sample_id_r  <= fetch_next_sample_id;
			fetch_valid_r           <= in_rd_en;

			mul_valid_r[ 0 ] <= fetch_valid_r;
			mul_valid_r[ 1:MUL_SBD_STAGES-1 ] <=
				mul_valid_r[ 0:MUL_SBD_STAGES-2 ];

			dq_valid_r <= mul_valid_r[ MUL_SBD_STAGES-1 ];

			add1_valid_r <= dq_valid_r;

			add2_valid_r <= add1_valid_r;

			out_valid_r <= out_valid;
			out_prev_wr_en_r <= out_wr_en;
		end
	end

	always_ff @ ( posedge clk )
	begin
		if ( pipe_wr_en )
		begin
			{ fetch_din_real_r, fetch_din_imag_r } <= { din_real, din_imag };

			mul_sample_id_r[ 0 ] <= fetch_sample_id_r;
			mul_sample_id_r[ 1:MUL_SBD_STAGES-1 ] <= mul_sample_id_r[ 0:MUL_SBD_STAGES-2 ];
	
			dq_p1_r <= dq_p1;
			dq_p2_r <= dq_p2;
			dq_p3_r <= dq_p3;
			dq_sample_id_r <= mul_sample_id_r[ MUL_SBD_STAGES-1 ];
	
			add1_v_real_r <= add1_v_real;
			add1_v_imag_r <= add1_v_imag;
			add1_in1_real_r <= add1_in1_real;
			add1_in1_imag_r <= add1_in1_imag;
			add1_sample_id_r <= dq_sample_id_r;

			add2_out1_real_r <= add2_out1_real;
			add2_out1_imag_r <= add2_out1_imag;
			add2_out2_real_r <= add2_out2_real;
			add2_out2_imag_r <= add2_out2_imag;
			add2_sample_id_r <= add1_sample_id_r;
	
			out_prev_sample_id_r <= add2_sample_id_r;

		end
	end	

	generate
	if ( DBG )
	begin
		always_ff @( negedge clk )
		begin: dbg_dspl_proc
			if ( in_rd_en )
			begin
				$display( "@ %0t stage %0d input  %h+%hj", $time, STAGE, din_real, din_imag  );
			end
			if ( out_wr_en )
			begin
				$display( "@ %0t stage %0d output %h+%hj", $time, STAGE, dout_real, dout_imag  );
			end

			if ( pipe_wr_en && fetch_valid_r )
			begin
				$display( "@ %0t stage %0d mul %h+%hj * %h+%hj", $time, STAGE, mul_in_a, mul_in_b, mul_in_c, mul_in_d );
			end

			if ( pipe_wr_en && add1_valid_r )
			begin
				$display(
					"@ %0t stage %0d add1 clocked in1:%h+%hj, v: %h+%hj",
					$time, STAGE, add1_in1_real_r, add1_in1_imag_r, add1_v_real_r, add1_v_imag_r
				);
			end

		end: dbg_dspl_proc
	end
	endgenerate

endmodule: fft_stage

