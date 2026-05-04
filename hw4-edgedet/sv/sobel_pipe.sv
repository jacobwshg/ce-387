
import globals_pkg :: FRAME_HEIGHT;
import globals_pkg :: FRAME_WIDTH;
import globals_pkg :: SAFE_BYTE_WIDTH;
import globals_pkg :: BYTE_WIDTH;
import globals_pkg :: BOX_DIM;
import globals_pkg :: box_t;

module sobel_pipe
#(
	parameter int FRAME_HEIGHT = globals_pkg::FRAME_HEIGHT,
	parameter int FRAME_WIDTH  = globals_pkg::FRAME_WIDTH
)
(
	input logic clk, rst,

	input  logic in_empty,
	input  logic [ BYTE_WIDTH-1:0 ] din,
	output logic in_rd_en,

	input logic out_full,
	output logic [ BYTE_WIDTH-1:0 ] dout,
	output logic out_wr_en,

	output logic done
);

	//
	// pipe regs write enable
	//
	logic pipe_wr_en;

	box_t box;
	logic fetch_valid;

	logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad, vgrad;
	logic compute_valid; 

	sobel_pipe_out #(
		.FRAME_HEIGHT( FRAME_HEIGHT ),
		.FRAME_WIDTH ( FRAME_WIDTH )
	) out_stage (
		.clk( clk ), .rst( rst ),
		.in_valid( compute_valid ), .hgrad( hgrad ), .vgrad( vgrad ),
		.out_full( out_full ),
		.pipe_wr_en( pipe_wr_en ),
		.out_wr_en( out_wr_en ),
		.dout( dout ),
		.done( done )
	);

	sobel_pipe_compute compute_stage
	(
		.clk( clk ), .rst( rst ),
		.pipe_wr_en( pipe_wr_en ),
		.in_valid( fetch_valid ), .box( box ),
		.hgrad( hgrad ), .vgrad( vgrad ), .out_valid( compute_valid )
	); 

	sobel_pipe_fetch #(
		.FRAME_HEIGHT( FRAME_HEIGHT ),
		.FRAME_WIDTH ( FRAME_WIDTH )
	) fetch_stage (
		.clk( clk ), .rst( rst ),
		.pipe_wr_en( pipe_wr_en ),
		.in_empty( in_empty ), .din( din ),
		.in_rd_en( in_rd_en ),
		.box( box ),
		.out_valid( fetch_valid )
	);

endmodule: sobel_pipe

