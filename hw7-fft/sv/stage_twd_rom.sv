
import twiddles_pkg::TWIDDLES;

module stage_twd_rom
#(
	parameter int STAGE = 2,
	parameter int ADDR_WIDTH = ( 0===STAGE ) ? STAGE+1 : STAGE
)
(
	input  logic clk,
	input  logic [ ADDR_WIDTH-1:0 ] rd_addr,
	input  logic rd_en,
	output logic signed [ 0:1 ] [ 31:0 ] dout
);
	// # of twiddles for this stage
	// stage 0:1; stage 1:2; stage 2:4
	localparam int SIZE = 2 ** STAGE;

	localparam logic signed [ 0:SIZE-1 ] [ 0:1 ] [ 31:0 ] stage_twds =
		TWIDDLES[ STAGE ][ 0:SIZE-1 ];

	logic [ ADDR_WIDTH-1:0 ] rd_addr_r;

	always_ff @ ( posedge clk )
	if ( rd_en )
	begin
		rd_addr_r <= rd_addr;
	end

	assign dout = stage_twds[ rd_addr_r ];

endmodule: stage_twd_rom

