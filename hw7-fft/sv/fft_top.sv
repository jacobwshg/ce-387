
module fft_top #(
	parameter int N = 32,
	parameter int DATA_WIDTH = 32,
	parameter int FIFO_DEPTH = 16
)(
	input logic clk,
	input logic rst,

	input logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] in_din,
	input logic in_valid,
	input logic in_wr_en,
	input logic out_rd_en,

	output logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] out_dout,
	output logic out_valid,
	output logic out_empty,
	output logic in_full
);

	logic signed [ 0:1 ] [ DATA_WIDTH-1:0 ] in_dout, out_din;
	logic 
		in_rd_en, in_empty, out_wr_en, out_full;

	fifo #(
		.FIFO_DATA_WIDTH( 1 + 2 * DATA_WIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	) fifo_in_inst (
		.reset( rst ),
		.wr_clk( clk ),
		.wr_en( in_wr_en ),
		.din( { in_in_valid, in_din } ),
		.full( in_full ),
		.rd_clk( clk ),
		.rd_en( in_rd_en ),
		.dout( { in_out_valid, in_dout } ),
		.empty( in_empty )
	);

	fft #(
		.N( N ),
		.DATA_WIDTH( DATA_WIDTH )
	) fft_inst (
		.clk( clk ), .rst( rst ),
		.din( in_dout ),
		.in_valid( in_out_valid ),
		.in_empty( in_empty ),
		.out_full( out_full ),

		.dout( out_din ),
		.out_valid( out_in_valid ),
		.out_wr_en( out_wr_en ),
		.in_rd_en( in_rd_en )
	);

	fifo #(
		.FIFO_DATA_WIDTH( 1 + 2 * DATA_WIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	) fifo_out_inst (
		.reset( rst ),
		.wr_clk( clk ),
		.wr_en( out_wr_en ),
		.din( { out_in_valid, out_din } ),
		.full( out_full ),
		.rd_clk( clk ),
		.rd_en( out_rd_en ),
		.dout( { out_out_valid, out_dout } ),
		.empty( out_empty )
	);

endmodule: fft_top

