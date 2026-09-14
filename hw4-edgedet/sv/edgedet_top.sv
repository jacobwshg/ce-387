
import globals_pkg::FRAME_WIDTH;
import globals_pkg::FRAME_HEIGHT;
import globals_pkg::COL_ID_WIDTH;
import globals_pkg::ROW_ID_WIDTH;
import globals_pkg::BYTE_WIDTH;
import globals_pkg::FIFO_DEPTH;

module edgedet_top 
#(
	parameter FRAME_WIDTH  = globals_pkg::FRAME_WIDTH,
	parameter FRAME_HEIGHT = globals_pkg::FRAME_HEIGHT,
	parameter COL_ID_WIDTH = globals_pkg::COL_ID_WIDTH,
	parameter ROW_ID_WIDTH = globals_pkg::ROW_ID_WIDTH
)
(
	input  logic clk,
	input  logic rst,

	input  logic in_wr_en,
	input  logic [ 0:2 ] [ BYTE_WIDTH-1:0 ] din,
	output logic in_full,

	input  logic out_rd_en,
	output logic [ BYTE_WIDTH-1:0 ] dout,
	output logic out_empty

);

	logic in_gs_wr_en;
	logic [ 0:2 ] [ BYTE_WIDTH-1:0 ] in_gs_din;
	logic in_gs_full;
	logic in_gs_rd_en;
	logic [ 0:2 ] [ BYTE_WIDTH-1:0 ] in_gs_dout;
	logic in_gs_empty;

	logic [ BYTE_WIDTH-1:0 ] gs_sobel_din;
	logic gs_sobel_wr_en;
	logic gs_sobel_full;
	logic [ BYTE_WIDTH-1:0 ] gs_sobel_dout;
	logic gs_sobel_rd_en;
	logic gs_sobel_empty;

	logic sobel_out_wr_en;
	logic [ BYTE_WIDTH-1:0 ] sobel_out_din;
	logic sobel_out_full;
	logic sobel_out_rd_en;
	logic [ BYTE_WIDTH-1:0 ] sobel_out_dout;
	logic sobel_out_empty;

	assign in_gs_wr_en = in_wr_en;
	assign in_gs_din = din;
	assign in_full = in_gs_full;

	assign sobel_out_rd_en = out_rd_en;
	assign dout = sobel_out_dout;
	assign out_empty = sobel_out_empty;

	fifo #(
		.DWIDTH( 3 * BYTE_WIDTH ),
		.DEPTH ( FIFO_DEPTH )
	) f_in_gs (
		.clk( clk ),
		.rst( rst ),

		.wr_en( in_gs_wr_en ),
		.din  ( in_gs_din ),
		.full ( in_gs_full ),

		.rd_en( in_gs_rd_en ),
		.dout ( in_gs_dout ),
		.empty( in_gs_empty )
	);

	fifo #(
		.DWIDTH( BYTE_WIDTH ),
		.DEPTH ( FIFO_DEPTH )
	) f_gs_sobel (
		.clk( clk ), .rst( rst ),

		.wr_en( gs_sobel_wr_en ),
		.din  ( gs_sobel_din ),
		.full ( gs_sobel_full ),

		.rd_en( gs_sobel_rd_en ),
		.dout ( gs_sobel_dout ),
		.empty( gs_sobel_empty )
	);

	fifo #(
		.DWIDTH( BYTE_WIDTH ),
		.DEPTH ( FIFO_DEPTH )
	) f_sobel_out (
		.clk( clk ), .rst( rst ),

		.wr_en( sobel_out_wr_en ),
		.din  ( sobel_out_din ),
		.full ( sobel_out_full ),

		.rd_en( sobel_out_rd_en ),
		.dout ( sobel_out_dout ),
		.empty( sobel_out_empty )
	);

	grayscale
	gs (
		.clk( clk ), .rst( rst ),

		.in_empty ( in_gs_empty ),
		.din      ( in_gs_dout ),
		.in_rd_en ( in_gs_rd_en ),

		.out_full ( gs_sobel_full ),
		.dout     ( gs_sobel_din ),
		.out_wr_en( gs_sobel_wr_en )
	);

	sobel #(
		.FRAME_WIDTH ( FRAME_WIDTH ), .FRAME_HEIGHT( FRAME_HEIGHT ),
		.COL_ID_WIDTH( COL_ID_WIDTH ), .ROW_ID_WIDTH( ROW_ID_WIDTH )
	) sobel (
		.clk( clk ), .rst( rst ),

		.in_empty( gs_sobel_empty ),
		.din     ( gs_sobel_dout ),
		.in_rd_en( gs_sobel_rd_en ),

		.out_full ( sobel_out_full ),
		.dout     ( sobel_out_din ),
		.out_wr_en( sobel_out_wr_en )
	);

endmodule: edgedet_top

