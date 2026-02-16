
module udpreader_top(
	input logic clock,
	input logic reset,

	input logic in_we,
	input logic [ 7:0 ] in_din,
	input logic in_sof_in,
	input logic in_eof_in,
	input logic out_re,

	output logic in_full,
	output logic out_empty,
	output logic [ 7:0 ] out_dout,
	output logic out_sof_out,
	output logic out_eof_out,

	output logic pkt_done,
	output logic sum_true
);

	localparam FIFO_SIZE = 32;

	logic [ 7:0 ] in_dout;
	logic in_re;
	logic in_empty;
	logic in_sof_out, in_eof_out;

	logic [ 7:0 ] out_din;
	logic out_we;
	logic out_full;
	logic out_sof_in, out_eof_in;

	fifo_ctrl #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 8 )
	) fifo_in_inst (
		.reset( reset ),

		.wr_clk( clock ),
		.wr_en ( in_we ),
		.din   ( in_din ),
		.sof_in( in_sof_in ),
		.eof_in( in_eof_in ),
		.full  ( in_full ),

		.rd_clk ( clock ),
		.rd_en  ( in_re ),
		.dout   ( in_dout ),
		.sof_out( in_sof_out ),
		.eof_out( in_eof_out ),
		.empty  ( in_empty )
	);

	fifo_ctrl #(
		.FIFO_BUFFER_SIZE( FIFO_SIZE ),
		.FIFO_DATA_WIDTH( 8 )
	) fifo_out_inst (
		.reset( reset ),

		.wr_clk( clock ),
		.wr_en ( out_we ),
		.din   ( out_din ),
		.sof_in( out_sof_in ),
		.eof_in( out_eof_in ),
		.full  ( out_full ),

		.rd_clk ( clock ),
		.rd_en  ( out_re ),
		.dout   ( out_dout ),
		.sof_out( out_sof_out ),
		.eof_out( out_eof_out ),
		.empty  ( out_empty )
	);

	udpreader reader_inst
	(
		.clock( clock ),
		.reset( reset ),

		.in_empty  ( in_empty ),
		.in_dout   ( in_dout ),
		.out_full  ( out_full ),
		.in_sof_out( in_sof_out ),
		.in_eof_out( in_eof_out ),

		.in_re     ( in_re ),
		.out_we    ( out_we ),
		.out_din   ( out_din ),
		.out_sof_in( out_sof_in ),
		.out_eof_in( out_eof_in ),

		.pkt_done( pkt_done ),
		.sum_true( sum_true )
	);

endmodule: udpreader_top

