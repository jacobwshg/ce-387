
module fft #(
	parameter int N = 32,
	parameter int DWIDTH = 32
)
(
	input logic clk,
	input logic rst,

	input logic signed [ 0:1 ] [ DWIDTH-1:0 ] din,
	input logic in_empty,
	input logic out_full,

	output logic signed [ 0:1 ] [ DWIDTH-1:0 ] dout,
	output logic out_wr_en,
	output logic in_rd_en,

	output logic done
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

	typedef enum logic [ 1:0 ] {
		S_REORDER, S_RUN, S_DONE
	} fsm_state_t;
	fsm_state_t fsm_state, fsm_state_c;

	/*
	 * in_idx = order of arrival from upstream FIFO
	 * wr_addr = bit-reversed
	 */
	logic [ STAGE_CNT-1:0 ]
		ROB_in_idx, ROB_in_idx_c,
		ROB_wr_addr;
	/* extra bit for detecting wrap past entire reorder buffer */
	logic [ STAGE_CNT:0 ]
		ROB_rd_addr, ROB_rd_addr_c;
	logic [ ( 2*DWIDTH )-1:0 ] ROB_din, ROB_dout;
	logic ROB_wr_en;

	/*
	 * For S stages, there should be S+1 internal FIFOs:
	 * one for ROB output, then one for each stage's output
	 */
	logic [ DWIDTH*2-1:0 ]
		fifo_din [ 0:STAGE_CNT ], fifo_dout [ 0:STAGE_CNT ];
	logic
		fifo_wr_en [ 0:STAGE_CNT ], fifo_full [ 0:STAGE_CNT ],
		fifo_rd_en [ 0:STAGE_CNT ], fifo_empty [ 0:STAGE_CNT ];

	/*
	 * Number of samples that have been read from final stage 
	 * and sent downstream
	 */
	logic [ STAGE_CNT:0 ] out_sample_cnt, out_sample_cnt_c;

	bram #(
		.BRAM_ADDR_WIDTH( STAGE_CNT ),
		.BRAM_DATA_WIDTH( 2 * DWIDTH )
	) reorder_buff (
		.clock  ( clk ),
		.rd_addr( ROB_rd_addr_c[ STAGE_CNT-1:0 ] ),
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
					.DWIDTH( DWIDTH ),
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

	assign done = 1'( fsm_state == S_DONE );

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			fsm_state <= S_REORDER;
			ROB_in_idx <= 'h0;
			ROB_rd_addr <= 'h0;
			out_sample_cnt <= 'h0;
		end
		else
		begin
			fsm_state <= fsm_state_c;
			ROB_in_idx <= ROB_in_idx_c;
			ROB_rd_addr <= ROB_rd_addr_c;
			out_sample_cnt <= out_sample_cnt_c;
		end
	end	

	always_comb
	begin
		fsm_state_c = fsm_state;

		ROB_in_idx_c = ROB_in_idx;
		ROB_wr_addr = 1'h0;
		/* perform bit reversal */
		for ( int b=0; b<$clog2(N); ++b )
		begin
			ROB_wr_addr[ $clog2(N)-1-b ] = ROB_in_idx[ b ];
		end

		ROB_rd_addr_c = ROB_rd_addr;
		ROB_din = 'hX;
		ROB_wr_en = 1'b0;

		fifo_wr_en[ 0 ] = 1'b0;
		fifo_din[ 0 ] = 'hX;
		fifo_rd_en[ STAGE_CNT ] = 1'b0;

		dout[ 0 ] = 'sh0;
		dout[ 1 ] = 'sh0;
		out_wr_en = 1'b0;
		in_rd_en = 1'b0;

		out_sample_cnt_c = out_sample_cnt;

		case ( fsm_state )
			S_REORDER:
			begin
				if ( !in_empty )
				begin
					in_rd_en = 1'b1;

					ROB_din = { din[ 0 ], din[ 1 ] };
					ROB_wr_en = 1'b1;
					/* data will write to the reordered ROB_wr_addr */
					$display( "" );
					$display(
						"@%0t writing data %08h + %08hj, ROB_in_idx = %0d = %08b, ROB_wr_addr = %0d = %08b",
						$time, din[ 0 ], din[ 1 ], ROB_in_idx, ROB_in_idx, ROB_wr_addr, ROB_wr_addr
					);
					$display( "" );


					ROB_in_idx_c = ROB_in_idx + 1;

					if ( ROB_in_idx_c == 0 )
					begin
						// all samples read
						fsm_state_c = S_RUN;
						ROB_rd_addr_c = 'h0;
					end

				end
			end

			S_RUN:
			begin
				if ( !fifo_full[ 0 ] )
				begin
					// can send a sample to stage 1
					fifo_wr_en[ 0 ] = 1'b1;
					fifo_din  [ 0 ] = ROB_dout;
					// keep reading the next ROB sample, even if we wrap, so
					// as to flush the pipeline
					ROB_rd_addr_c = ROB_rd_addr + 1'h1;
				end

				if ( ( !fifo_empty[ STAGE_CNT ] ) && !out_full )
				begin
					// allow final stage output to flow out
					out_wr_en = 1'b1;
					fifo_rd_en[ STAGE_CNT ] = 1'b1;
					dout = fifo_dout[ STAGE_CNT ];

					out_sample_cnt_c = out_sample_cnt + 1'h1;
					if ( out_sample_cnt_c == N )
					begin
						fsm_state_c = S_DONE;
					end
				end
			end

			S_DONE:
			begin
			end

			default:
			begin
				fsm_state_c = S_REORDER;

				ROB_rd_addr_c = 'h0;
				ROB_in_idx_c = 'h0;
				ROB_wr_addr = 'h0;
				ROB_din = 'hX;
				ROB_wr_en = 1'b0;

				in_rd_en = 1'b0;
				out_wr_en = 1'b0;
				dout[ 0 ] = 'shX;
				dout[ 1 ] = 'shX;

				out_sample_cnt_c = 'h0;
			end
		endcase
	end

endmodule: fft

