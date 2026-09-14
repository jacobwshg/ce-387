
import globals_pkg::SAFE_BYTE_WIDTH;
import globals_pkg::BYTE_WIDTH;
import globals_pkg::SOBEL_BOX_DIM;

module sobel
#(
	parameter int FRAME_WIDTH  = 720,
	parameter int FRAME_HEIGHT = 540,
	parameter int COL_ID_WIDTH = $clog2( FRAME_WIDTH ),
	parameter int ROW_ID_WIDTH = $clog2( FRAME_HEIGHT )
)
(
	input  logic clk,
	input  logic rst,

	input  logic in_empty,
	input  logic [ BYTE_WIDTH-1:0 ] din,
	output logic in_rd_en,

	input  logic out_full,
	output logic [ BYTE_WIDTH-1:0 ] dout,
	output logic out_wr_en
);

	//
	// pipe regs write enable
	//
	logic pipe_en;

	logic [ BYTE_WIDTH-1:0 ] px_in;
	logic in_valid;

	logic [ 0:SOBEL_BOX_DIM-1 ] [ BYTE_WIDTH-1:0 ] box_right_col;
	logic fetch_valid;

	logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad, vgrad;
	logic compute_valid; 

	logic [ BYTE_WIDTH-1:0 ] px_out;
	logic output_valid;

	sobel_pipe_fetch #(
		.FRAME_WIDTH ( FRAME_WIDTH ),
		.FRAME_HEIGHT( FRAME_HEIGHT ),
		.COL_ID_WIDTH( COL_ID_WIDTH ),
		.ROW_ID_WIDTH( ROW_ID_WIDTH )
	) fetch_stage (
		.clk( clk ), .rst( rst ), .pipe_en( pipe_en ),

		.px_in( px_in ),
		.in_valid( in_valid ),

		.box_right_col_out( box_right_col ),
		.out_valid( fetch_valid )
	);

	sobel_pipe_compute
	compute_stage (
		.clk( clk ), .rst( rst ), .pipe_en( pipe_en ),

		.box_right_col_in( box_right_col ),
		.in_valid( fetch_valid ),

		.hgrad_out( hgrad ), .vgrad_out( vgrad ),
		.out_valid( compute_valid )
	); 

	sobel_pipe_output #(
		.FRAME_WIDTH ( FRAME_WIDTH ),
		.FRAME_HEIGHT( FRAME_HEIGHT ),
		.COL_ID_WIDTH( COL_ID_WIDTH ),
		.ROW_ID_WIDTH( ROW_ID_WIDTH )
	) output_stage (
		.clk( clk ), .rst( rst ), .pipe_en( pipe_en ),

		.hgrad_in( hgrad ), .vgrad_in( vgrad ),
		.in_valid( compute_valid ),

		.px_out( px_out ),
		.out_valid( output_valid )
	);

	assign pipe_en = !out_full;

	assign px_in = din;
	assign in_valid = !in_empty;

	assign in_rd_en = pipe_en && !in_empty;

	assign dout = px_out;
	assign out_wr_en = pipe_en && output_valid;

endmodule: sobel

