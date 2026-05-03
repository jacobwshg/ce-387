
import globals_pkg :: IMG_WIDTH;
import globals_pkg :: IMG_HEIGHT;
import globals_pkg :: BYTE_WIDTH;
import globals_pkg :: RGB_WIDTH;
import globals_pkg :: FIFO_DEPTH;

module edgedet_top 
#(
	parameter WIDTH  = IMG_WIDTH,
	parameter HEIGHT = IMG_HEIGHT
)
(
	input  logic clock,
	input  logic reset,

	input  logic in_gs_wr_en,
	input  logic [ RGB_WIDTH-1:0 ] in_gs_din,
	input  logic sobel_out_rd_en,

	output logic in_gs_full,
	output logic sobel_out_empty,
	output logic [ BYTE_WIDTH-1:0 ] sobel_out_dout,

	output logic sobel_done

);

	logic [ RGB_WIDTH-1:0 ] in_gs_dout;
	logic in_gs_empty;
	logic in_gs_rd_en;

	logic [ BYTE_WIDTH-1:0 ] gs_sobel_din;
	logic gs_sobel_wr_en;
	logic gs_sobel_full;
	logic [ BYTE_WIDTH-1:0 ] gs_sobel_dout;
	logic gs_sobel_rd_en;
	logic gs_sobel_empty;

	logic [ BYTE_WIDTH-1:0 ] sobel_out_din;
	logic sobel_out_full;
	logic sobel_out_wr_en;

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_DEPTH ),
		.FIFO_DATA_WIDTH( RGB_WIDTH )
	) f_in_gs (
		.reset ( reset ),

		.wr_clk( clock ),
		.wr_en ( in_gs_wr_en ),
		.din   ( in_gs_din ),
		.full  ( in_gs_full ),

		.rd_clk( clock ),
		.rd_en ( in_gs_rd_en ),
		.dout  ( in_gs_dout ),
		.empty ( in_gs_empty )
	);

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_DEPTH ),
		.FIFO_DATA_WIDTH( BYTE_WIDTH )
	) f_gs_sobel (
		.reset ( reset ),

		.wr_clk( clock ),
		.wr_en ( gs_sobel_wr_en ),
		.din   ( gs_sobel_din ),
		.full  ( gs_sobel_full ),

		.rd_clk( clock ),
		.rd_en ( gs_sobel_rd_en ),
		.dout  ( gs_sobel_dout ),
		.empty ( gs_sobel_empty )
	);

	fifo #(
		.FIFO_BUFFER_SIZE( FIFO_DEPTH ),
		.FIFO_DATA_WIDTH( BYTE_WIDTH )
	) f_sobel_out (
		.reset ( reset ),

		.wr_clk( clock ),
		.wr_en ( sobel_out_wr_en ),
		.din   ( sobel_out_din ),
		.full  ( sobel_out_full ),

		.rd_clk( clock ),
		.rd_en ( sobel_out_rd_en ),
		.dout  ( sobel_out_dout ),
		.empty ( sobel_out_empty )
	);

	grayscale gs (
		.clock( clock ),
		.reset( reset ),

		.in_empty ( in_gs_empty ),
		.in_dout  ( in_gs_dout ),
		.out_full ( gs_sobel_full ),

		.in_rd_en ( in_gs_rd_en ),
		.out_wr_en( gs_sobel_wr_en ),
		.out_din  ( gs_sobel_din )
	);

	sobel_pipe sobel (
		.clk( clock ), .rst( reset ),

		.in_empty( gs_sobel_empty ),
		.din     ( gs_sobel_dout ),
		.in_rd_en( gs_sobel_rd_en ),

		.out_full ( sobel_out_full ),
		.dout     ( sobel_out_din ),
		.out_wr_en( sobel_out_wr_en ),

		.done( sobel_done )
	);

endmodule: edgedet_top

