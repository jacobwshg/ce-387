
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
	localparam logic signed [ 1:STAGE_CNT ] [ 0:(N/2)-1 ] [ 0:1 ] [ DATA_WIDTH-1:0 ] twdls = 
	{
		{
			{32'sh00004000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00000000,32'shffffc000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00002d41,32'shffffd2bf}, {32'sh00000000,32'shffffc000}, {32'shffffd2bf,32'shffffd2bf},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00003b20,32'shffffe783}, {32'sh00002d41,32'shffffd2bf}, {32'sh0000187d,32'shffffc4e0},
			{32'sh00000000,32'shffffc000}, {32'shffffe783,32'shffffc4e0}, {32'shffffd2bf,32'shffffd2bf}, {32'shffffc4e0,32'shffffe783},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00003ec5,32'shfffff384}, {32'sh00003b20,32'shffffe783}, {32'sh00003536,32'shffffdc72}, 
			{32'sh00002d41,32'shffffd2bf}, {32'sh0000238e,32'shffffcaca}, {32'sh0000187d,32'shffffc4e0}, {32'sh00000c7c,32'shffffc13b},
			{32'sh00000000,32'shffffc000}, {32'shfffff384,32'shffffc13b}, {32'shffffe783,32'shffffc4e0}, {32'shffffdc72,32'shffffcaca},
			{32'shffffd2bf,32'shffffd2bf}, {32'shffffcaca,32'shffffdc72}, {32'shffffc4e0,32'shffffe783}, {32'shffffc13b,32'shfffff384}
		}
	};

	typedef enum logic [ 1:0 ] { S_REORDER, S_RUN } state_t;
	state_t state, state_c;

	logic signed [ STAGE_CNT-1:0 ] [ 0:1 ] [ DATA_WIDTH-1:0 ] stages_dout;
	logic signed [ STAGE_CNT-1:0 ] stages_out_valid;

	/*
	 * in_idx = sequential, order of arrival from upstream FIFO
	 * wr_addr = bit-reversed
	 */
	logic [ $clog2(N)-1:0 ]
		rob_in_idx, rob_in_idx_c,
		rob_wr_addr,
		rob_rd_addr, rob_rd_addr_c;
	logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] rob_din, rob_dout;
	logic rob_wr_en;
	logic rob_out_valid;

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
		.w  ( twdls[1][0] ),
		.din( rob_dout ),
		.in_valid( rob_out_valid ),
		.dout( stages_dout[0] ),
		.out_valid( stages_out_valid[0] )
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
				.stage_twdls( twdls[stage] ),

				.din     ( stages_dout[ stage-2 ] ),
				.in_valid( stages_out_valid[ stage-2 ] ),

				.dout     ( stages_dout[ stage-1 ] ),
				.out_valid( stages_out_valid[ stage-1 ] )
			);
		end
	endgenerate

	bram #(
		.BRAM_ADDR_WIDTH( $clog2(N) ),
		.BRAM_DATA_WIDTH( 2 * DATA_WIDTH )
	) reorder_buff (
		.clock  ( clk ),
		.rd_addr( rob_rd_addr ),
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
			rob_in_idx <= 1'h0;
			rob_rd_addr <= 1'h0;
		end
		else
		begin
			state <= state_c;
			rob_in_idx <= rob_in_idx_c;
			rob_rd_addr <= rob_rd_addr_c;
		end
	end	

	always_comb
	begin
		state_c = state;

		stages_dout = '{ 'h0 };
		stages_out_valid = '{ 'h0 };

		rob_in_idx_c = rob_in_idx;
		rob_wr_addr = 1'h0;
		/* perform bit reversal */
		for ( int b=0; b<$clog2(N); ++b )
		begin
			rob_wr_addr[ $clog2(N)-1-b ] = rob_in_idx[ b ];
		end
		rob_rd_addr_c = rob_rd_addr;
		rob_din = '{ 'h0 };	
		rob_wr_en = 1'b0;
		rob_out_valid = 1'b0;

		dout = '{ 'h0 };
		out_valid = 1'b0;
		out_wr_en = 1'b0;
		in_rd_en = 1'b0;

		case ( state )
			S_REORDER:
			begin
				if ( !in_empty )
				begin
					in_rd_en = 1'b1;
					if ( in_valid )
					begin
						rob_din = din;
						rob_wr_en = 1'b1;
						rob_in_idx_c += 1'h1;
					end
					if ( rob_in_idx == ~'h0 )
					begin
						state_c = S_RUN;
						/*
						 * Avoid reading rob[0] twice in S_RUN
						 */
						rob_rd_addr_c = 1'h1;
					end
				end
			end
			S_RUN:
			begin
				if ( !out_full )
				begin
					rob_out_valid = 1'h1;

					dout = stages_dout[ STAGE_CNT-1 ];
					out_valid = stages_out_valid[ STAGE_CNT ];

					out_wr_en = 1'b1;
					rob_rd_addr_c += 1;
					if ( rob_rd_addr == ~'h0 )
					begin
						state_c = S_REORDER;
					end
				end
			end
		endcase
	end

endmodule: fft

