module matmul_top
#(
	parameter DATA_WIDTH = 32,
	parameter MAT_DIM_WIDTH = 3,
	parameter MAT_DIM_SIZE = 2 ** MAT_DIM_WIDTH,
	parameter ADDR_WIDTH = MAT_DIM_WIDTH * 2,
	parameter MAT_SIZE = 2 ** ADDR_WIDTH,
)
(
	input logic clk,
	input logic rst,
	input logic strt,

	input logic x_we,
	input logic y_we,
	input logic [ DATA_WIDTH-1 : 0 ] x_w_data,
	input logic [ DATA_WIDTH-1 : 0 ] y_w_data,
	input logic [ MAT_DIM_WIDTH-1 : 0 ] x_w_bank_id,
	input logic [ MAT_DIM_WIDTH-1 : 0 ] y_w_bank_id,
	input logic [ MAT_DIM_WIDTH-1 : 0 ] x_w_bank_addr,
	input logic [ MAT_DIM_WIDTH-1 : 0 ] y_w_bank_addr,

	input logic [ ADDR_WIDTH-1 : 0 ] z_r_addr,
	output logic [ DATA_WIDTH-1 : 0 ] z_r_data,
	output logic done
);

	/* used by MM unit */
	logic [ MAT_DIM_WIDTH-1 : 0 ]
		x_r_bank_id,
		y_r_bank_id,
		x_r_bank_addr,
		y_r_bank_addr;
	logic [ MAT_DIM_SIZE- : 0 ][ DATA_WIDTH-1 : 0 ] 
		x_r_row,
		y_r_col;
	logic z_we;
	logic [ ADDR_WIDTH-1 : 0 ] z_w_addr;
	logic [ DATA_WIDTH-1 : 0 ] z_w_data;

	/* Z as a flat 1D BRAM */
	bram #(
		.BRAM_ADDR_WIDTH( ADDR_WIDTH ),
		.BRAM_DATA_WIDTH( DATA_WIDTH )
	) z_inst (
		.clock( clk ),
		.rd_addr( z_r_addr ),
		.wr_addr( z_w_addr ),
		.wr_en( z_we ),
		.din( z_w_data ),
		.dout( z_r_data )
	);

	/* X, Y as banked BRAMs */
	banked_bram #(
		.DATA_WIDTH      ( DATA_WIDTH ),
		.BANK_ID_WIDTH   ( MAT_DIM_WIDTH ),
		.BANK_CNT        ( MAT_DIM_SIZE ),
		.BANK_ADDR_WIDTH ( MAT_DIM_WIDTH ),
		.BANK_SIZE       ( MAT_DIM_SIZE )
	)
	x_inst (
		.clock       ( clk ),
		.we          ( x_we )
		.din         ( x_w_data ),
		.bank_w_id   ( x_w_bank_id ),
		.bank_w_addr ( x_w_bank_addr ),
		.bank_r_addr ( x_r_bank_addr ),
		.dout        ( x_r_row )
	),
	y_inst (
		.clock       ( clk ),
		.we          ( y_we )
		.din         ( y_w_data ),
		.bank_w_id   ( y_w_bank_id ),
		.bank_w_addr ( y_w_bank_addr ),
		.bank_r_addr ( y_r_bank_addr ),
		.dout        ( y_r_col )
	);

	/* MM unit */
	matmul #(
		.DATA_WIDTH    ( DATA_WIDTH ),
		.MAT_DIM_WIDTH ( MAT_DIM_WIDTH ),
		.MAT_DIM_SIZE  ( MAT_DIM_SIZE ),
		.ADDR_WIDTH    ( ADDR_WIDTH ),
		.MAT_SIZE      ( MAT_SIZE )
	) mm_inst (
		.clk      ( clk ),
		.rst      ( rst ),
		.strt     ( strt ),
		.x_r_row  ( x_r_row ),
		.y_r_col  ( y_r_col ),
		.i        ( x_r_bank_addr ),
		.j        ( y_r_bank_addr ),
		.z_we     ( z_we ),
		.z_addr   ( z_w_addr ),
		.z_w_data ( z_w_data ),
		.done     ( done )
	);

endmodule

