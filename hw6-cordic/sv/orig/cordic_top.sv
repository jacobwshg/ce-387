
module cordic_top (
	input logic clk,
	input logic rst,

	input logic signed [ 31:0 ] in_din,
	input logic in_we,
	input logic out_re,

	output logic in_full,
	output logic signed [ 1:0 ] [ 15:0 ] out_dout,
	output logic out_empty
);

	logic signed [ 31:0 ] in_dout;
	logic in_empty;
	logic out_full;

	logic in_re;
	logic signed [ 1:0 ] [ 15:0 ] out_din;
	logic out_we;

	localparam FIFO_DEPTH = 32;

	cordic
	cordic_inst(
		.clk( clk ),
		.rst( rst ),
		.in_dout( in_dout ),
		.in_empty( in_empty ),
		.out_full( out_full ),
		.in_re( in_re ),
		.out_din( out_din ),
		.out_we( out_we )
	);

	fifo #(
		.FIFO_DATA_WIDTH( 32 ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	)
	rad_fifo_inst(
		.reset( rst ),
		.wr_clk( clk ),
		.wr_en( in_we ),
		.din( in_din ),
		.full( in_full ),
		.rd_clk( clk ),
		.rd_en( in_re ),
		.dout( in_dout ),
		.empty( in_empty )
	);

	fifo #(
		.FIFO_DATA_WIDTH( 32 ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	)
	sincos_fifo_inst(
		.reset( rst ),
		.wr_clk( clk ),
		.wr_en( out_we ),
		.din( out_din ),
		.full( out_full ),
		.rd_clk( clk ),
		.rd_en( out_re ),
		.dout( out_dout ),
		.empty( out_empty )
	);
	
endmodule: cordic_top

