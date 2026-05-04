module matmul_top
#(
	parameter DATA_WIDTH = 32,
	parameter MAT_DIM_WIDTH = 3,
	parameter MAT_DIM_SIZE = 2 ** MAT_DIM_WIDTH,
	parameter ADDR_WIDTH = MAT_DIM_WIDTH * 2,
	parameter MAT_SIZE = 2 ** ADDR_WIDTH
)
(
	input logic clk,
	input logic rst,
	input logic strt,

	input logic x_wr_en [ 0:MAT_DIM_SIZE-1 ],
	input logic y_wr_en [ 0:MAT_DIM_SIZE-1 ],
	input logic [ DATA_WIDTH-1:0 ] x_wr_data,
	input logic [ DATA_WIDTH-1:0 ] y_wr_data,
	input logic [ MAT_DIM_WIDTH-1:0 ] x_wr_bank_addr,
	input logic [ MAT_DIM_WIDTH-1:0 ] y_wr_bank_addr,

	input logic [ ADDR_WIDTH-1 : 0 ] z_rd_addr,
	output logic [ DATA_WIDTH-1 : 0 ] z_rd_data,
	output logic done
);

	/* used by MM unit */
	logic [ MAT_DIM_WIDTH-1:0 ]
		x_rd_bank_addr,
		y_rd_bank_addr;
	logic [ DATA_WIDTH-1:0 ] 
		x_rd_row [ 0:MAT_DIM_SIZE-1 ],
		y_rd_col [ 0:MAT_DIM_SIZE-1 ];
	logic z_wr_en;
	logic [ ADDR_WIDTH-1:0 ] z_wr_addr;
	logic [ DATA_WIDTH-1:0 ] z_wr_data;

	/* Z as a flat 1D BRAM */
	bram #(
		.BRAM_ADDR_WIDTH( ADDR_WIDTH ),
		.BRAM_DATA_WIDTH( DATA_WIDTH )
	) z_inst (
		.clock   ( clk ),
		.rd_addr ( z_rd_addr ),
		.wr_addr ( z_wr_addr ),
		.wr_en   ( z_wr_en ),
		.din     ( z_wr_data ),
		.dout    ( z_rd_data )
	);

	bram_block #(
		.BRAM_ADDR_WIDTH ( MAT_DIM_WIDTH ),
		.BANK_DATA_WIDTH ( DATA_WIDTH ),
		.BANK_CNT        ( MAT_DIM_SIZE ),
		.BRAM_DATA_WIDTH ( DATA_WIDTH * MAT_DIM_SIZE )
	)
	x_inst (
		.clock   ( clk ),
		.rd_addr ( x_rd_bank_addr ),
		.wr_addr ( x_wr_bank_addr ),
		.wr_en   ( x_wr_en ),
		.din     ( x_wr_data ),
		.dout    ( x_rd_row )
	),
	y_inst (
		.clock   ( clk ),
		.rd_addr ( y_rd_bank_addr ),
		.wr_addr ( y_wr_bank_addr ),
		.wr_en   ( y_wr_en ),
		.din     ( y_wr_data ),
		.dout    ( y_rd_col )
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
		.x_rd_row ( x_rd_row ),
		.y_rd_col ( y_rd_col ),
		.i        ( x_rd_bank_addr ),
		.j        ( y_rd_bank_addr ),
		.z_wr_en  ( z_wr_en ),
		.z_wr_addr( z_wr_addr ),
		.z_wr_data( z_wr_data ),
		.done     ( done )
	);

endmodule

