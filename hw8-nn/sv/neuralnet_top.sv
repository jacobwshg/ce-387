
import biases_pkg::*;
import weights_pkg::*;

module neuralnet_top #(
	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14,

	parameter int INPUT_SIZE = 784,
	parameter int LAYER_CNT = 2,
	parameter int LAYER_SIZES [ 0:LAYER_CNT-1 ] = { 10, 10 },

	parameter int FIFO_DEPTH = 16
)(
	input logic clk,
	input logic rst,

	input logic signed [ DATA_WIDTH-1:0 ] feature_in,

	output logic done,
	output logic label_out
);

	logic 
		in_l0_wr_en, in_l0_full, 
		in_l0_rd_en, in_l0_empty;
	logic
		l0_l1_wr_en, l0_l1_full, 
		l0_l1_rd_en, l0_l1_empty;
	logic
		l1_amax_wr_en, l1_amax_full, 
		l1_amax_rd_en, l1_amax_empty;

	logic signed [ DATA_WIDTH-1:0 ]
		layer0_din, layer0_dout,
		layer1_din, layer1_dout,
		argmax_din;

	fifo #(
		.FIFO_DATA_WIDTH( DATA_WIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	) fifo_in_l0_inst (
		.reset ( rst ),

		.wr_clk( clk ),
		.wr_en ( in_l0_wr_en ),
		.din   ( feature_in ),
		.full  ( in_l0_full ),

		.rd_clk( clk ),
		.rd_en ( in_l0_rd_en ),
		.dout  ( layer0_din ),
		.empty ( in_l0_empty )
	);

	layer #(
		.DATA_WIDTH( DATA_WIDTH ),
		.FRAC_WIDTH( FRAC_WIDTH ),
		.INPUT_SIZE( INPUT_SIZE ),
		.OUTPUT_SIZE( LAYER_SIZES[0] ),
		.IDX_WIDTH( $clog2( INPUT_SIZE )+1 ),
		.LAYER_BIASES( LAYER0_BIASES ),
		.LAYER_WEIGHTS( LAYER0_WEIGHTS )
	) layer0_inst (
		.clk      ( clk ),
		.rst      ( rst ),

		.din      ( layer0_din ),
		.in_empty ( in_l0_empty ),
		.out_full ( l0_l1_full ),

		.dout     ( layer0_dout ),
		.in_rd_en ( in_l0_rd_en ),
		.out_wr_en( l0_l1_wr_en )
	);

	fifo #(
		.FIFO_DATA_WIDTH( DATA_WIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	) fifo_l0_l1_inst (
		.reset ( rst ),

		.wr_clk( clk ),
		.wr_en ( l0_l1_wr_en ),
		.din   ( layer0_dout ),
		.full  ( l0_l1_full ),

		.rd_clk( clk ),
		.rd_en ( l0_l1_rd_en ),
		.dout  ( layer1_din ),
		.empty ( l0_l1_empty )
	);

/*********/
	layer #(
		.DATA_WIDTH( DATA_WIDTH ),
		.FRAC_WIDTH( FRAC_WIDTH ),
		.INPUT_SIZE( INPUT_SIZE ),
		.OUTPUT_SIZE( LAYER_SIZES[0] ),
		.IDX_WIDTH( $clog2( INPUT_SIZE )+1 ),
		.LAYER_BIASES( LAYER1_BIASES ),
		.LAYER_WEIGHTS( LAYER1_WEIGHTS )
	) layer1_inst (
		.clk( clk ),
		.rst( rst ),

		.din      ( layer1_din ),
		.in_empty ( l0_l1_empty ),
		.out_full ( l1_amax_full ),

		.dout     ( layer1_dout ),
		.in_rd_en ( l0_l1_rd_en ),
		.out_wr_en( l1_amax_wr_en )
	);

	fifo #(
		.FIFO_DATA_WIDTH( DATA_WIDTH ),
		.FIFO_BUFFER_SIZE( FIFO_DEPTH )
	) fifo_l1_amax_inst (
		.reset ( rst ),

		.wr_clk( clk ),
		.wr_en ( l1_amax_wr_en ),
		.din   ( layer1_dout ),
		.full  ( l1_amax_full ),

		.rd_clk( clk ),
		.rd_en ( l1_amax_rd_en ),
		.dout  ( argmax_din ),
		.empty ( l1_amax_empty )
	);

	argmax #(
		.DATA_WIDTH( DATA_WIDTH ),
		.INPUT_SIZE( LAYER_SIZES[ LAYER_CNT-1 ] ),
	) argmax_inst (
		.clk( clk ),
		.rst( rst ),
		.in_empty( l1_amax_empty ),
		.din     ( argmax_din ),
		.in_rd_en( l1_amax_rd_en ),
		.done    ( done ),
		.i_max   ( label_out )
	);	

endmodule: neuralnet_top

