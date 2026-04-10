
import globals_pkg::FIFO_DEPTH;
import globals_pkg::PIPE_FIFO_DEPTH;

module fft_top #(
	parameter int N = 32,				
	parameter int DWIDTH = 32,				
	parameter int FIFO_DEPTH = globals_pkg::FIFO_DEPTH,			
	parameter int PIPE_FIFO_DEPTH = globals_pkg::PIPE_FIFO_DEPTH			
)
(
	input logic clk,
	input logic rst,

	input logic signed [ 0:1 ] [ DWIDTH-1:0 ] in_din,
	input logic in_wr_en,
	input logic out_rd_en,

	output logic signed [ 0:1 ] [ DWIDTH-1:0 ] out_dout,
	output logic out_empty,
	output logic in_full,

	output logic done
);

	logic signed [ 0:1 ] [ DWIDTH-1:0 ] in_dout, out_din;
	logic 
		in_rd_en, in_empty,
		out_wr_en, out_full;

	fifo #(
		.FIFO_DATA_WIDTH( 2 * DWIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	) fifo_in (
		.reset( rst ),

		.wr_clk( clk ),
		.wr_en( in_wr_en ),
		.din( { in_din[ 0 ], in_din[ 1 ] } ),
		.full( in_full ),

		.rd_clk( clk ),
		.rd_en( in_rd_en ),
		.dout( { in_dout[ 0 ], in_dout[ 1 ] } ),
		.empty( in_empty )
	);

	fft #(
		.N( N ),
		.DWIDTH( DWIDTH ),
		.PIPE_FIFO_DEPTH( PIPE_FIFO_DEPTH )
	) fft_inst (
		.clk( clk ), .rst( rst ),

		.din( in_dout ),
		.in_empty( in_empty ),
		.out_full( out_full ),

		.dout( out_din ),
		.out_wr_en( out_wr_en ),
		.in_rd_en( in_rd_en ),

		.done( done )
	);

	fifo #(
		.FIFO_DATA_WIDTH( 2 * DWIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	) fifo_out (
		.reset( rst ),

		.wr_clk( clk ),
		.wr_en( out_wr_en ),
		.din( { out_din[ 0 ], out_din[ 1 ] } ),
		.full( out_full ),

		.rd_clk( clk ),
		.rd_en( out_rd_en ),
		.dout( { out_dout[ 0 ], out_dout[ 1 ] } ),
		.empty( out_empty )
	);

endmodule: fft_top

