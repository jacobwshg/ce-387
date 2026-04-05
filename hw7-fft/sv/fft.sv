
module fft #(
	parameter int N = 32,
	parameter int DWIDTH = 32
)
(
	input logic clk,
	input logic rst,

	input logic signed [ 0:1 ] [ DWIDTH-1:0 ] din,
	input logic in_valid,
	input logic in_empty,
	input logic out_full,

	output logic signed [ 0:1 ] [ DWIDTH-1:0 ] dout,
	output logic out_valid,
	output logic out_wr_en,
	output logic in_rd_en
);

	import twdls_pkg::TWDLS;

	/*
	 * 8 samples -> 3 stages
	 */
	localparam int STAGE_CNT = $clog2( N );
	/*
	 * Actually only need at most N/2 instead of N twdl factors for each stage,
	 * since each butterfly takes a pair of inputs
	 */
	localparam int N_DEFAULT = 32;

	typedef enum logic [ 1:0 ] { S_REORDER, S_RUN } state_t;
	state_t state, state_c;

	//logic signed [ STAGE_CNT-1:0 ] [ 0:1 ] [ DWIDTH-1:0 ]
	//	stages_dout, stages_dout_c;
	//logic [ STAGE_CNT-1:0 ]
	//	stages_out_valid, stages_out_valid_c;

	/*
	 * in_idx = sequential, order of arrival from upstream FIFO
	 * wr_addr = bit-reversed
	 */
	logic [ STAGE_CNT-1:0 ]
		ROB_in_idx, ROB_in_idx_c,
		ROB_wr_addr;
	/* extra bit for detecting wrap past entire reorder buffer */
	logic [ STAGE_CNT:0 ]
		ROB_rd_addr, ROB_rd_addr_c;
	logic [ ( DWIDTH*2 )-1:0 ] ROB_din, ROB_dout;
	logic ROB_wr_en;

	/* reorder buffer output -> stage 1 input */
	logic signed [ 0:1 ] [ DWIDTH-1:0 ] stage1_din;
	logic stage1_in_valid;

	/*
	 * For S stages, there should be S+1 internal FIFOs:
	 * one for ROB output, then one for each stage's output
	 */
	logic [ DWIDTH*2-1:0 ]
		fifo_din [ 0:STAGE_CNT ], fifo_dout [ 0:STAGE_CNT ];
	logic
		fifo_wr_en [ 0:STAGE_CNT ], fifo_full [ 0:STAGE_CNT ],
		fifo_rd_en [ 0:STAGE_CNT ], fifo_empty [ 0:STAGE_CNT ];

	bram #(
		.BRAM_ADDR_WIDTH( $clog2(N) ),
		.BRAM_DWIDTH( 2 * DWIDTH )
	) reorder_buff (
		.clock  ( clk ),
		.rd_addr( ROB_rd_addr[ $clog2(N)-1:0 ] ),
		.wr_addr( ROB_wr_addr ),
		.wr_en  ( ROB_wr_en ),
		.din    ( ROB_din ),
		.dout   ( ROB_dout )
	); 

	/*
	* Stage 1 has its own template because its buffer is a 
	* single element deep; with the normal stage template, 
	* its buffer address will be of width 0, which is illegal.
	* Also, it requires reading the only buffer element 
	* immediately after it is written, which leads to its buffer
	* being implemented with FF rather than BRAM.
	*/
	generate
		genvar s;
		for ( s=0; s<=STAGE_CNT; ++s )
		begin
			fifo #(
				.FIFO_DATA_WIDTH( 2 * DWIDTH ),
				.FIFO_BUFFER_SIZE( 4 )
			) pipe_fifo (
				.reset( rst ),
				.wr_clk( clk ), .wr_en( fifo_wr_en[ s ] ),
				.din( fifo_din[ s ] ), .full( fifo_full[ s ] ),
				.rd_clk( clk ), .rd_en( fifo_rd_en[ s ] ),
				.dout( fifo_dout[ s ] ), .empty( fifo_empty[ s ] )
			);

			if ( s == 1 )
			begin
				fft_stage1 #(
					.N ( N ),
					.DWIDTH( DWIDTH ),
					.STAGE1_TWDL( TWDLS[ 0 ][ 0 ] )
				) stage1_inst (
					.clk( clk ), .rst( rst ),
					.din      ( fifo_dout [ 0 ] ),
					.in_empty ( fifo_empty[ 0 ] ),
					.out_full ( fifo_full [ 1 ] ),
					.in_rd_en ( fifo_rd_en[ 0 ] ),
					.dout     ( fifo_din  [ 1 ] ),
					.out_wr_en( fifo_wr_en[ 1 ] )
				);
			end
			else if ( s > 1 )
			begin
				fft_stage #(
					.STAGE( s ),
					.N( N ),
					.DWIDTH( DWIDTH )
					.STAGE_TWDLS( TWDLS[ s-1 ][ 0:( 1<<( s-1 ) )-1 ] )
				) stage_inst (
					.clk( clk ), .rst( rst ),
					.din      ( fifo_dout [ s-1 ] ),
					.in_empty ( fifo_empty[ s-1 ] ),
					.out_full ( fifo_full [ s ] ),
					.in_rd_en ( fifo_rd_en[ s-1 ] ),
					.dout     ( fifo_din  [ s ] ),
					.out_wr_en( fifo_wr_en[ s ] )
				);
			end
		end
	endgenerate

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_REORDER;
			ROB_in_idx <= 'h0;
			ROB_rd_addr <= 'h0;
			for ( int s=0; s<STAGE_CNT; ++s )
			begin
				stages_dout[ s ][0] <= 'sh0;
				stages_dout[ s ][1] <= 'sh0;
				stages_out_valid[ s ] <= 1'b0;
			end
		end
		else
		begin
			state <= state_c;
			ROB_in_idx <= ROB_in_idx_c;
			ROB_rd_addr <= ROB_rd_addr_c;
/*
			for ( int s=0; s<STAGE_CNT; ++s )
			begin
				stages_dout[ s ][0] <= stages_dout_c[ s ][0];
				stages_dout[ s ][1] <= stages_dout_c[ s ][1];
				stages_out_valid[ s ] <= stages_out_valid_c[ s ];
			end
*/
			stages_dout <= stages_dout_c;
			stages_out_valid <= stages_out_valid_c;

		end
	end	

	always_comb
	begin
		state_c = state;

		ROB_in_idx_c = ROB_in_idx;
		ROB_wr_addr = 1'h0;
		/* perform bit reversal */
		for ( int b=0; b<$clog2(N); ++b )
		begin
			ROB_wr_addr[ $clog2(N)-1-b ] = ROB_in_idx[ b ];
		end

		ROB_din = 'h0;	
		ROB_wr_en = 1'b0;

		dout[0] = 'sh0;
		dout[1] = 'sh0;
		out_valid = 1'b0;
		out_wr_en = 1'b0;
		in_rd_en = 1'b0;

		stage1_din[0] = 'sh0;
		stage1_din[1] = 'sh0;
		stage1_in_valid = 1'b0;
		ROB_rd_addr_c = ROB_rd_addr;

		case ( state )
			S_REORDER:
			begin
				if ( ~in_empty )
				begin
					/*
					 * As long as upstream FIFO has a value, we read one, but
					 * don't commit the value to reorder buffer unless it is
					 * valid (not a bubble)
					 */
					in_rd_en = 1'b1;
					//$display( "FFT in data: %h %h, in_valid: %1b", din[0], din[1], in_valid );
					if ( in_valid )
					begin

						//$display( "FFT data in valid. data: %08h %08h, ROB_in_idx: %0bb, ROB_wr_addr: %0bb", din[0], din[1], ROB_in_idx, ROB_wr_addr );

						ROB_din = { din[0], din[1] };
						ROB_wr_en = 1'b1;
						/* data will write to the reordered ROB_wr_addr */

						ROB_in_idx_c = ROB_in_idx_c + 1;
					end

					if ( ROB_in_idx_c == 0 )
					begin
						//$display( "MOVING TO S_RUN" );
						state_c = S_RUN;
						ROB_rd_addr_c = 'h0;
					end

				end
			end
			S_RUN:
			begin
				stage1_in_valid = ROB_rd_addr==0? 1'b0: 1'b1;

				if ( ~out_full )
				begin
					/* allow bram rd output to flow into stage 1 */
					stage1_din[0] = ROB_dout[ ( 2*DWIDTH )-1:DWIDTH ];
					stage1_din[1] = ROB_dout[ DWIDTH-1:0 ];
				//$display( "@ %0t FFT S_RUN: stage1_din { %8h %8h }, ROB_rd_addr_c %0d", $time, stage1_din[0], stage1_din[1], ROB_rd_addr_c );

					/* allow final stage output to flow out */
					dout = stages_dout[ STAGE_CNT-1 ];
					out_valid = stages_out_valid[ STAGE_CNT-1 ];
					out_wr_en = 1'b1;

					ROB_rd_addr_c = ROB_rd_addr_c + 1;

					/*
					if ( ROB_rd_addr[ $clog2(N) ] == 1'b1 )
					begin
						$display( "MOVING TO S_REORDER" );
						state_c = S_REORDER;
						ROB_rd_addr_c = 'h0;
					end
					*/
				end
			end
			default:
			begin
				state_c = S_REORDER;
				ROB_in_idx_c = 'h0;
				ROB_wr_addr = 'h0;
				ROB_rd_addr_c = 'h0;
				ROB_din = 'hx;
				ROB_wr_en = 1'b0;
				stage1_in_valid = 1'b0;
				dout[0] = 'shx;
				dout[1] = 'shx;
				out_valid = 1'b0;
				out_wr_en = 1'b0;
				in_rd_en = 1'b0;
			end
		endcase
	end

endmodule: fft

