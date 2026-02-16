
module fifo_ctrl #(
	parameter FIFO_DATA_WIDTH = 32,
	parameter FIFO_BUFFER_SIZE = 256
)
(
	input logic reset, 

	input logic wr_clk,
	input logic wr_en,
	input logic sof_in,
	input logic eof_in,
	input logic [ FIFO_DATA_WIDTH + 1:0 ] din,
	output logic full,

	input logic rd_clk,
	input logic rd_en,
	output logic sof_out,
	output logic eof_out,
	output logic [ FIFO_DATA_WIDTH + 1:0 ] dout,
	output logic empty
);

	fifo #(
		.FIFO_DATA_WIDTH ( FIFO_DATA_WIDTH + 2 ),
		.FIFO_BUFFER_SIZE( FIFO_BUFFER_SIZE )
	) fifo_inst (
		.reset( reset ),

		.wr_clk( wr_clk ),
		.wr_en ( wr_en ),
		.din   ( { eof_in, sof_in, din } ),
		.full  ( full ),

		.rd_clk( rd_clk ),
		.rd_en ( rd_en ),
		.dout  ( { eof_out, sof_out, dout } ),
		.empty ( empty )
	);

endmodule: fifo_ctrl


