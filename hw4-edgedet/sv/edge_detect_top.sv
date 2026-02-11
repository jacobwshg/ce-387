
module edge_detect_top 
#(
	parameter WIDTH  = 720,
	parameter HEIGHT = 540
)
(
	input  logic clock,
	input  logic reset,

	input  logic in_gs_we,
	input  logic [ 23:0 ] in_gs_din,
	input  logic sobel_out_re,

	output logic in_gs_full,
	output logic sobel_out_empty,
	output logic [ 7:0 ] sobel_out_dout
);

	localparam FIFO_SIZE = 32;

	logic [ 23:0 ] in_gs_dout;
	logic in_gs_empty;
	logic in_gs_re;

	logic [ 7:0 ] gs_sobel_din;
	logic gs_sobel_we;
	logic gs_sobel_full;
	logic [ 7:0 ] gs_sobel_dout;
	logic gs_sobel_re;
	logic gs_sobel_empty;

	logic [ 7:0 ] sobel_out_din;
	logic sobel_out_full;
	logic sobel_out_we;

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 24 )
	) in_gs_fifo (
		.reset ( reset ),

		.wr_clk( clock ),
		.wr_en ( in_gs_we ),
		.din   ( in_gs_din ),
		.full  ( in_gs_full ),

		.rd_clk( clock ),
		.rd_en ( in_gs_re ),
		.dout  ( in_gs_dout ),
		.empty ( in_gs_empty )
	);

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 8 )
	) gs_sobel_fifo (
		.reset ( reset ),

		.wr_clk( clock ),
		.wr_en ( gs_sobel_we ),
		.din   ( gs_sobel_din ),
		.full  ( gs_sobel_full ),

		.rd_clk( clock ),
		.rd_en ( gs_sobel_re ),
		.dout  ( gs_sobel_dout ),
		.empty ( gs_sobel_empty )
	);

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 8 )
	) sobel_out_fifo (
		.reset ( reset ),

		.wr_clk( clock ),
		.wr_en ( sobel_out_we ),
		.din   ( sobel_out_din ),
		.full  ( sobel_out_full ),

		.rd_clk( clock ),
		.rd_en ( sobel_out_re ),
		.dout  ( sobel_out_dout ),
		.empty ( sobel_out_empty )
	);

	grayscale
	gs_inst (
		.clock( clock ),
		.reset( reset ),

		.in_empty ( in_gs_empty ),
		.in_dout  ( in_gs_dout ),
		.out_full ( gs_sobel_full ),

		.in_rd_en ( in_gs_re ),
		.out_wr_en( gs_sobel_we ),
		.out_din  ( gs_sobel_din )
	);

	sobel #(
		.IMG_WIDTH ( WIDTH ),
		.IMG_HEIGHT( HEIGHT )
	) sobel_inst (
		.clk( clock ),
		.rst( reset ),

		.in_empty( gs_sobel_empty ),
		.in_dout ( gs_sobel_dout ),
		.out_full( sobel_out_full ),

		.in_rd_en ( gs_sobel_re ),
		.out_wr_en( sobel_out_we ),
		.out_din  ( sobel_out_din )
	);

endmodule

