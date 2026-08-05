
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
	 * stage 0:1 ( 1 elem, for addr 0 only )
	 * stage 1:1 ( 2 elems )
	 * stage 2:2 ( 4 elems )
	 * stage 3:3 ( 8 elems )
	 */
	localparam int MEM_ADDR_WIDTH = ( 0===STAGE ) ? ( STAGE+1 ) : STAGE;
	localparam int IN2_FLAGBIT_POS = ( 0===STAGE ) ? 0 : MEM_ADDR_WIDTH;
	localparam int STEPID_WIDTH = SAMPLE_ID_WIDTH - MEM_ADDR_WIDTH - ( ( 0===STAGE ) ? 0 : 1 );

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

	// fetch stage
	logic [ SAMPLE_ID_WIDTH-1:0 ]
		fetch_sample_id_r,      // exposed to mul
		fetch_next_sample_id_r, fetch_next_sample_id_c; // stage-internal use
	logic signed [ DWIDTH-1:0 ]
		fetch_din_real_r, fetch_din_imag_r,
		fetch_w_real_r, fetch_w_imag_r; // driven by twdl tbl
	logic fetch_valid_r;
	logic fetch_is_in2;

	// butterfly in2 * twdl multiply stage
	// if sample is in1, no multiply, buffer it in BRAM
	// if sample is in2, clock prods and also assert in1 rd addr
	logic signed [ DWIDTH-1:0 ]
		mul_wr_i2r_r, mul_wr_i2i_r, mul_wi_i2i_r, mul_wi_i2r_r;
	logic [ SAMPLE_ID_WIDTH-1:0 ] mul_sample_id_r;
	logic mul_valid_r;
	logic mul_is_in2;
	logic [ MEM_ADDR_WIDTH-1:0 ] mul_buf_addr;

	// dequantize stage ( in2 )
	// also clock loaded in1
	logic signed [ DWIDTH-1:0 ]
		dq_wr_i2r_r, dq_wr_i2i_r, dq_wi_i2i_r, dq_wi_i2r_r;
	logic signed [ DWIDTH-1:0 ]
		dq_bufout_real_r, dq_bufout_imag_r;
	logic [ SAMPLE_ID_WIDTH-1:0 ] dq_sample_id_r;
	logic dq_valid_r;
	logic dq_is_in2;
	logic [ MEM_ADDR_WIDTH-1:0 ] dq_buf_addr;

	// add stage
	//
	logic signed [ DWIDTH-1:0 ]
		add_out1_real_r, add_out1_imag_r,
		add_out2_real_r, add_out2_imag_r;
	logic [ SAMPLE_ID_WIDTH-1:0 ] add_sample_id_r;
	logic add_valid_r;
	logic add_is_in2;
	logic signed [ DWIDTH-1:0 ]
		add_in1_real, add_in1_imag,
		add_v_real, add_v_imag,
		add_out1_real, add_out1_imag,
		add_out2_real, add_out2_imag;
	
	logic out_is_in2;
	
	always_comb
	begin
		// as long as !out_full, out FIFO can be written,
		// and thus pipe regs can be written without losing samples;
		// pipe_wr_en doesn't care about in_empty
		pipe_wr_en = !out_full;

		// if !pipe_wr_en, the input sample can't be clocked, so definitely !in_rd_en;
		// if pipe_wr_en, need to additionally check that the sample is valid
		// ( !in_empty )
		in_rd_en = pipe_wr_en && !in_empty;

		bfly_in1_rd_addr = 'h0;
		bfly_in1_wr_addr = 'h0;
		{ bfly_in1_wr_real, bfly_in1_wr_imag } = '{ default: 'sh0 };
		bfly_in1_wr_en = 1'b0;
 		bfly_out2_rd_addr = 'h0;
		bfly_out2_wr_addr = 'h0;
		{ bfly_out2_wr_real, bfly_out2_wr_imag } = '{ default: 'sh0 };
		bfly_out2_wr_en = 1'b0;

		fetch_next_sample_id_c = fetch_next_sample_id_r;
		if ( in_rd_en )
		begin
			fetch_next_sample_id_c = fetch_next_sample_id_r + 1'h1;
		end
		// if current sample is valid, read ahead for next sample's matching twiddle
		bfly_w_rd_addr = ( 0===STAGE ) ? 1'h0 : fetch_next_sample_id_c[ MEM_ADDR_WIDTH-1:0 ];
		fetch_is_in2   = fetch_next_sample_id_r[ IN2_FLAGBIT_POS ];

		mul_buf_addr = ( 0===STAGE ) ? 1'h0 : fetch_sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
		mul_is_in2   = fetch_sample_id_r[ IN2_FLAGBIT_POS ];
		if ( fetch_valid_r )
		begin
			if ( !mul_is_in2 )
			begin
				{ bfly_in1_wr_real, bfly_in1_wr_imag } =
					{ fetch_din_real_r, fetch_din_imag_r };
				bfly_in1_wr_addr = mul_buf_addr;
				bfly_in1_wr_en   = fetch_valid_r;
				$strobe( "in1 raw input %h @ addr %h, wr_en=%b", bfly_in1_buf.din, bfly_in1_buf.wr_addr, bfly_in1_wr_en );
			end
			else
			begin
				bfly_in1_rd_addr = mul_buf_addr;
			end
		end

		dq_is_in2 = mul_sample_id_r[ IN2_FLAGBIT_POS ];
		dq_buf_addr = ( 0===STAGE ) ? 1'h0 : mul_sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
		if ( !dq_is_in2 )
		begin
			bfly_out2_rd_addr = dq_buf_addr;
		end

		add_is_in2 = dq_sample_id_r[ IN2_FLAGBIT_POS ];
		{ add_in1_real, add_in1_imag } = { dq_bufout_real_r, dq_bufout_imag_r };
		// default assignments
		{ add_v_real,    add_v_imag } = '{ default: 'sh0 };
		{ add_out1_real, add_out1_imag } = '{ default: 'sh0 };
		{ add_out2_real, add_out2_imag } = '{ default: 'sh0 };
		if ( !add_is_in2 )
		begin
			{ add_out2_real, add_out2_imag } = { bfly_out2_rd_real, bfly_out2_rd_imag };
			if (
				0===STAGE &&
				( add_sample_id_r === dq_sample_id_r + 1'h1 ) &&
				add_valid_r
			)
			begin // forward
				{ add_out2_real, add_out2_imag } = { add_out2_real_r, add_out2_imag_r };
			end
		end
		else
		begin
			add_v_real = ( dq_wr_i2r_r - dq_wi_i2i_r );
			add_v_imag = ( dq_wr_i2i_r + dq_wi_i2r_r );
			add_out1_real = add_in1_real + add_v_real;
			add_out1_imag = add_in1_imag + add_v_imag;
			add_out2_real = add_in1_real - add_v_real;
			add_out2_imag = add_in1_imag - add_v_imag;
		end

		{ dout_real, dout_imag } = '{ default: 'sh0 };
		out_is_in2 = add_sample_id_r[ IN2_FLAGBIT_POS ];
		out_wr_en = !out_full && add_valid_r;
		if ( !out_is_in2 )
		begin
			{ dout_real, dout_imag } = { add_out2_real_r, add_out2_imag_r };
			out_wr_en = out_wr_en && ( add_sample_id_r > STEP ); // in1 samples in step 0 read garbage out2
		end
		else
		begin
			{ dout_real, dout_imag } = { add_out1_real_r, add_out1_imag_r };
			out_wr_en = add_valid_r;

			bfly_out2_wr_addr = ( 0===STAGE ) ? 1'h0 : add_sample_id_r[ MEM_ADDR_WIDTH-1:0 ];
			{ bfly_out2_wr_real, bfly_out2_wr_imag } = { add_out2_real_r, add_out2_imag_r };
			bfly_out2_wr_en = add_valid_r;

		end

	end

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			fetch_next_sample_id_r <= 'h0;
			fetch_sample_id_r <= 'h0;
			///{ fetch_din_real_r, fetch_din_imag_r } <= '{ default: 'sh0 };
			///{ fetch_w_real_r,   fetch_w_imag_r }   <= '{ default: 'sh0 };
			fetch_valid_r <= 1'b0;

			///{ mul_wr_i2r_r, mul_wr_i2i_r, mul_wi_i2r_r, mul_wi_i2i_r }
			///	<= '{ default: 'sh0 };
			///mul_sample_id_r <= 'h0;
			mul_valid_r <= 1'b0;

			///{ dq_wr_i2r_r, dq_wr_i2i_r, dq_wi_i2i_r, dq_wi_i2r_r }
			///	<= '{ default: 'sh0 };
			dq_valid_r <= 1'b0;

			add_valid_r <= 1'b0;

		end
		else if ( pipe_wr_en )
		begin
			fetch_sample_id_r       <= fetch_next_sample_id_r;
			fetch_next_sample_id_r  <= fetch_next_sample_id_c;
			{ fetch_din_real_r, fetch_din_imag_r } <= { din_real, din_imag };

			globals_pkg::printtime();
			$strobe( "fetch_din_real : %h + %hj", fetch_din_real_r, fetch_din_imag_r );

			if ( fetch_is_in2 )
			begin
				$strobe( "in2 matching w : %h + %hj", bfly_w_rd_real, bfly_w_rd_imag );
				{ fetch_w_real_r, fetch_w_imag_r } <= { bfly_w_rd_real, bfly_w_rd_imag };
			end
			fetch_valid_r <= in_rd_en;

			if ( mul_is_in2 && fetch_valid_r )
			begin
				mul_wr_i2r_r <= fetch_w_real_r * fetch_din_real_r;
				mul_wr_i2i_r <= fetch_w_real_r * fetch_din_imag_r;
				mul_wi_i2i_r <= fetch_w_imag_r * fetch_din_imag_r;
				mul_wi_i2r_r <= fetch_w_imag_r * fetch_din_real_r;
				$strobe( "in2 reading in1 addr %h / %h", mul_buf_addr, bfly_in1_buf.rd_addr );
			end
			mul_sample_id_r <= fetch_sample_id_r;
			mul_valid_r <= fetch_valid_r;

			if ( dq_is_in2 && mul_valid_r )
			begin
				dq_wr_i2r_r <= quant_pkg::DEQUANT( mul_wr_i2r_r );
				dq_wr_i2i_r <= quant_pkg::DEQUANT( mul_wr_i2i_r );
				dq_wi_i2i_r <= quant_pkg::DEQUANT( mul_wi_i2i_r );
				dq_wi_i2r_r <= quant_pkg::DEQUANT( mul_wi_i2r_r );
				{ dq_bufout_real_r, dq_bufout_imag_r } <= { bfly_in1_rd_real, bfly_in1_rd_imag };
				$strobe( "in2 matching in1: %h + %hj", bfly_in1_rd_real, bfly_in1_rd_imag );
			end
			dq_sample_id_r <= mul_sample_id_r;
			dq_valid_r <= mul_valid_r;

			if ( dq_valid_r )
			begin
				{ add_out1_real_r, add_out1_imag_r } <= { add_out1_real, add_out1_imag };
				{ add_out2_real_r, add_out2_imag_r } <= { add_out2_real, add_out2_imag };
			end
			add_sample_id_r <= dq_sample_id_r;
			add_valid_r <= dq_valid_r;

		end
	end

endmodule: fft_stage
