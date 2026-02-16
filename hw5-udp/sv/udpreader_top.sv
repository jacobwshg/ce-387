
module udpreader_top(
	input logic clock,
	input logic reset,

	input logic [ 9:0 ] in_in,
	input logic in_we,
	input logic out_re,

	output logic in_full,
	output logic out_empty,
	output logic [ 9:0 ] out_out,

	output logic done,
	output logic sum_true
);

	localparam FIFO_SIZE = 32;

	logic [ 9:0 ] in_out;
	logic in_re;
	logic in_empty;

	logic [ 9:0 ] out_in;
	logic out_we;
	logic out_full;

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 10 )
	) fifo_in_inst (
		.reset( reset ),

		.wr_clk( clock ),
		.wr_en ( in_we ),
		.din   ( in_in ),
		.full  ( in_full ),

		.rd_clk( clock ),
		.rd_en ( in_re ),
		.dout  ( in_out ),
		.empty ( in_empty )
	);

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 10 )
	) fifo_out_inst (
		.reset( reset ),

		.wr_clk( clock ),
		.wr_en ( out_we ),
		.din   ( out_in ),
		.full  ( out_full ),

		.rd_clk( clock ),
		.rd_en ( out_re ),
		.dout  ( out_out ),
		.empty ( out_empty )
	);

	udpreader reader_inst
	(
		.clock( clock ),
		.reset( reset ),

		.in_empty( in_empty ),
		.in_out  ( in_out ),
		.out_full( out_full ),

		.in_re  ( in_re ),
		.out_we ( out_we ),
		.out_in ( out_in ),

		.done    ( done ),
		.sum_true( sum_true )
	);

endmodule: udpreader_top

