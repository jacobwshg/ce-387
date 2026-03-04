
module fft #(
	parameter int N = 32,
	parameter int DATA_WIDTH = 32
)
(
	input logic clk,
	input logic rst,

	input logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] din,
	input logic in_valid,
	input logic in_empty,
	input logic out_full,

	output logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] dout,
	output logic out_valid,
	output logic out_wr_en,
	output logic in_rd_en
);

	localparam int STAGE_CNT = $clog2( N );
	/*
	 * Actually only need at most N/2 instead of N twdl factors for each stage,
	 * since each butterfly takes a pair of inputs
	 */
	localparam int N_DEFAULT = 32;
	localparam logic signed [ 0:$clog2( N_DEFAULT )-1 ] [ 0:( N_DEFAULT/2 )-1 ] [ 0:1 ] [ DATA_WIDTH-1:0 ] twdls = 
	'{
		'{
			{32'sh00004000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		'{
			{32'sh00004000,32'sh00000000}, {32'sh00000000,32'shffffc000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		'{
			{32'sh00004000,32'sh00000000}, {32'sh00002d41,32'shffffd2bf}, {32'sh00000000,32'shffffc000}, {32'shffffd2bf,32'shffffd2bf},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		'{
			{32'sh00004000,32'sh00000000}, {32'sh00003b20,32'shffffe783}, {32'sh00002d41,32'shffffd2bf}, {32'sh0000187d,32'shffffc4e0},
			{32'sh00000000,32'shffffc000}, {32'shffffe783,32'shffffc4e0}, {32'shffffd2bf,32'shffffd2bf}, {32'shffffc4e0,32'shffffe783},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		'{
			{32'sh00004000,32'sh00000000}, {32'sh00003ec5,32'shfffff384}, {32'sh00003b20,32'shffffe783}, {32'sh00003536,32'shffffdc72}, 
			{32'sh00002d41,32'shffffd2bf}, {32'sh0000238e,32'shffffcaca}, {32'sh0000187d,32'shffffc4e0}, {32'sh00000c7c,32'shffffc13b},
			{32'sh00000000,32'shffffc000}, {32'shfffff384,32'shffffc13b}, {32'shffffe783,32'shffffc4e0}, {32'shffffdc72,32'shffffcaca},
			{32'shffffd2bf,32'shffffd2bf}, {32'shffffcaca,32'shffffdc72}, {32'shffffc4e0,32'shffffe783}, {32'shffffc13b,32'shfffff384}
		}
	};

	typedef enum logic [ 1:0 ] { S_REORDER, S_RUN } state_t;
	state_t state, state_c;

	logic signed [ STAGE_CNT-1:0 ] [ 0:1 ] [ DATA_WIDTH-1:0 ]
		stages_dout, stages_dout_c;
	logic [ STAGE_CNT-1:0 ]
		stages_out_valid, stages_out_valid_c;

	/*
	 * in_idx = sequential, order of arrival from upstream FIFO
	 * wr_addr = bit-reversed
	 */
	logic [ $clog2(N)-1:0 ]
		rob_in_idx, rob_in_idx_c,
		rob_wr_addr;
	/* extra bit for detecting wrap past entire reorder buffer */
	logic [ $clog2(N):0 ]
		rob_rd_addr, rob_rd_addr_c;
	logic [ (DATA_WIDTH*2)-1:0 ] rob_din, rob_dout;
	logic rob_wr_en;

	/* reorder buffer output -> stage 1 input */
	logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] stage1_din;
	logic stage1_in_valid;

	/*
	* Stage 1 has its own template because its buffer is a 
	* single element deep; with the normal stage template, 
	* its buffer address will be of width 0, which is illegal.
	* Also, it requires reading the only buffer element 
	* immediately after it is written, which leads to its buffer
	* being implemented with FF rather than BRAM.
	*/
	fft_stage1 #(
		.N ( N ),
		.DATA_WIDTH( DATA_WIDTH )
	) stg1_inst (
		.clk( clk ),
		.rst( rst ),
		.w  ( twdls[0][0] ),
		.din( stage1_din ),
		.in_valid( stage1_in_valid ),
		.dout( stages_dout_c[0] ),
		.out_valid( stages_out_valid_c[0] )
	);

	genvar stage;
	generate
		for ( stage=2; stage<=STAGE_CNT; ++stage )
		begin
			fft_stage #(
				.STAGE( stage ),
				.N( N ),
				.DATA_WIDTH( DATA_WIDTH )
			) stg_inst (
				.clk( clk ), .rst( rst ),
				.stage_twdls( twdls[ stage-1 ][ 0:(1<<(stage-1))-1 ] ),

				.din     ( stages_dout[ stage-2 ] ),
				.in_valid( stages_out_valid[ stage-2 ] ),

				.dout     ( stages_dout_c[ stage-1 ] ),
				.out_valid( stages_out_valid_c[ stage-1 ] )
			);
		end
	endgenerate

	bram #(
		.BRAM_ADDR_WIDTH( $clog2(N) ),
		.BRAM_DATA_WIDTH( 2 * DATA_WIDTH )
	) reorder_buff (
		.clock  ( clk ),
		.rd_addr( rob_rd_addr[ $clog2(N)-1:0 ] ),
		.wr_addr( rob_wr_addr ),
		.wr_en  ( rob_wr_en ),
		.din    ( rob_din ),
		.dout   ( rob_dout )
	); 

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_REORDER;
			rob_in_idx <= 'h0;
			rob_rd_addr <= 'h0;
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
			rob_in_idx <= rob_in_idx_c;
			rob_rd_addr <= rob_rd_addr_c;
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

		rob_in_idx_c = rob_in_idx;
		rob_wr_addr = 1'h0;
		/* perform bit reversal */
		for ( int b=0; b<$clog2(N); ++b )
		begin
			rob_wr_addr[ $clog2(N)-1-b ] = rob_in_idx[ b ];
		end

		rob_din = 'h0;	
		rob_wr_en = 1'b0;

		dout[0] = 'sh0;
		dout[1] = 'sh0;
		out_valid = 1'b0;
		out_wr_en = 1'b0;
		in_rd_en = 1'b0;

		stage1_din[0] = 'sh0;
		stage1_din[1] = 'sh0;
		stage1_in_valid = 1'b0;
		rob_rd_addr_c = rob_rd_addr;

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

						//$display( "FFT data in valid. data: %08h %08h, rob_in_idx: %0bb, rob_wr_addr: %0bb", din[0], din[1], rob_in_idx, rob_wr_addr );

						rob_din = { din[0], din[1] };
						rob_wr_en = 1'b1;
						/* data will write to the reordered rob_wr_addr */

						rob_in_idx_c = rob_in_idx_c + 1;
					end

					if ( rob_in_idx_c == 0 )
					begin
						//$display( "MOVING TO S_RUN" );
						state_c = S_RUN;
						rob_rd_addr_c = 'h0;
					end

				end
			end
			S_RUN:
			begin
				stage1_in_valid = rob_rd_addr==0? 1'b0: 1'b1;

				if ( ~out_full )
				begin
					/* allow bram rd output to flow into stage 1 */
					stage1_din[0] = rob_dout[ (2*DATA_WIDTH)-1:DATA_WIDTH ];
					stage1_din[1] = rob_dout[ DATA_WIDTH-1:0 ];
				//$display( "@ %0t FFT S_RUN: stage1_din { %8h %8h }, rob_rd_addr_c %0d", $time, stage1_din[0], stage1_din[1], rob_rd_addr_c );

					/* allow final stage output to flow out */
					dout = stages_dout[ STAGE_CNT-1 ];
					out_valid = stages_out_valid[ STAGE_CNT-1 ];
					out_wr_en = 1'b1;

					rob_rd_addr_c = rob_rd_addr_c + 1;

					/*
					if ( rob_rd_addr[ $clog2(N) ] == 1'b1 )
					begin
						$display( "MOVING TO S_REORDER" );
						state_c = S_REORDER;
						rob_rd_addr_c = 'h0;
					end
					*/
				end
			end
			default:
			begin
				state_c = S_REORDER;
				rob_in_idx_c = 'h0;
				rob_wr_addr = 'h0;
				rob_rd_addr_c = 'h0;
				rob_din = 'hx;
				rob_wr_en = 1'b0;
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

