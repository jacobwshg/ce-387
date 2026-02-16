
module udpreader_top(
	input logic clock,
	input logic reset,

	input logic [ 7:0 ] in_din,
	input logic in_we,
	input logic out_re,

	output logic in_full,
	output logic out_empty,
	output logic [ 7:0 ] out_dout,

	output logic done,
	output logic sum_true
);

	localparam FIFO_SIZE = 32;

	logic [ 7:0 ] in_dout;
	logic in_re;
	logic in_empty;

	logic [ 7:0 ] out_din;
	logic out_we;
	logic out_full;

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 8 )
	) fifo_in_inst (
		.reset( reset ),

		.wr_clk( clock ),
		.wr_en ( in_we ),
		.din   ( in_din ),
		.full  ( in_full ),

		.rd_clk( clock ),
		.rd_en ( in_re ),
		.dout  ( in_dout ),
		.empty ( in_empty )
	);

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 8 )
	) fifo_out_inst (
		.reset( reset ),

		.wr_clk( clock ),
		.wr_en ( out_we ),
		.din   ( out_din ),
		.full  ( out_full ),

		.rd_clk( clock ),
		.rd_en ( out_re ),
		.dout  ( out_dout ),
		.empty ( out_empty )
	);

	udpreader reader_inst
	(
		.clock( clock ),
		.reset( reset ),

		.in_empty( in_empty ),
		.in_dout ( in_dout ),
		.out_full( out_full ),

		.in_re  ( in_re ),
		.out_we ( out_we ),
		.out_din( out_din ),

		.done    ( done ),
		.sum_true( sum_true )
	);

endmodule: udpreader_top

