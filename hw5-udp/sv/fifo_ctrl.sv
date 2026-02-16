
module fifo_ctrl #(
	parameter FIFO_DATA_WIDTH = 32,
	parameter FIFO_BUFFER_SIZE = 256
)
(
	input logic reset, 

	input logic wr_clk,
	input logic wr_en,
	input logic [ FIFO_DATA_WIDTH-1:0 ] din,
	input logic sof_in,
	input logic eof_in,
	output logic full,

	input logic rd_clk,
	input logic rd_en,
	output logic [ FIFO_DATA_WIDTH-1:0 ] dout,
	output logic sof_out,
	output logic eof_out,
	output logic empty
);

	localparam I_DATA = 0;
	localparam I_CTRL = 1;

	logic [ 1:0 ] full_i, empty_i;

	fifo #(
		.FIFO_DATA_WIDTH ( FIFO_DATA_WIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_BUFFER_SIZE )
	) data_inst (
		.reset( reset ),

		.wr_clk( wr_clk ),
		.wr_en( wr_en ),
		.din( din ),
		.full( full_i[I_DATA] ),

		.rd_clk( rd_clk ),
		.rd_en( rd_en ),
		.dout( dout ),
		.empty( empty_i[I_DATA] )
	);

	fifo #(
		.FIFO_DATA_WIDTH ( 2 ),
		.FIFO_BUFFER_SIZE( FIFO_BUFFER_SIZE )
	) ctrl_inst (
		.reset( reset ),

		.wr_clk( wr_clk ),
		.wr_en ( wr_en ),
		.din   ( { sof_in, eof_in } ),
		.full  ( full_i[I_CTRL] ),

		.rd_clk( rd_clk ),
		.rd_en ( rd_en ),
		.dout  ( { sof_out, eof_out } ),
		.empty ( empty_i[I_CTRL] )
	);

	assign full = ( | full_i );
	assign empty = ( | empty_i );

endmodule: fifo_ctrl


