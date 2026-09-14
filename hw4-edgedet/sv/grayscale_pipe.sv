
import globals_pkg::BYTE_WIDTH;
import globals_pkg::RGB_SUM_WIDTH;

module grayscale_rom (
	input  logic clk,

	input  logic [ RGB_SUM_WIDTH-1:0 ] rgb_sum_in,
	input  logic rd_en,

	output logic [ BYTE_WIDTH-1:0 ] gs_px_out
);

	import grayscale_pkg::GRAYSCALE_TBL;

	logic [ RGB_SUM_WIDTH-1:0 ] rgb_sum_r;

	always_ff @( posedge clk )
	begin
		if ( rd_en ) rgb_sum_r <= rgb_sum_in;
	end

	assign gs_px_out = GRAYSCALE_TBL[ rgb_sum_r ];

endmodule: grayscale_rom

module grayscale (

	input  logic clk,
	input  logic rst,

	input  logic in_empty,
	input  logic [ 0:2 ] [ BYTE_WIDTH-1:0 ] din,
	output logic in_rd_en,

	input  logic out_full,
	output logic [ BYTE_WIDTH-1:0 ] dout,
	output logic out_wr_en

);
	logic pipe_en;

	logic in_valid;

	logic [ 0:2 ] [ BYTE_WIDTH-1:0 ] din_r;
	logic valid_r;
	logic [ RGB_SUM_WIDTH-1:0 ] rgb_sum;

	// ROM decode cycle
	logic valid_sh_r;
	logic [ BYTE_WIDTH-1:0 ] gs_rom_dout;

	logic [ BYTE_WIDTH-1:0 ] gs_px_r;
	logic valid_sh2_r;
	logic out_valid;

	grayscale_rom gs_rom(
		.clk( clk ),
		.rgb_sum_in( rgb_sum ), .rd_en( pipe_en ),
		.gs_px_out( gs_rom_dout )
	);

	always_ff @( posedge clk )
	begin
		if ( rst )
		begin
			valid_r     <= 1'b0;
			valid_sh_r  <= 1'b0;
			valid_sh2_r <= 1'b0;
		end
		else if ( pipe_en )
		begin
			valid_r     <= in_valid;
			valid_sh_r  <= valid_r;
			valid_sh2_r <= valid_sh_r;
		end

		if ( pipe_en )
		begin
			din_r[ 0:2 ] <= din[ 0:2 ];

			gs_px_r <= gs_rom_dout;
		end

	end

	assign pipe_en = !out_full;

	assign in_valid = !in_empty;
	assign in_rd_en = pipe_en && in_valid;

	assign out_valid = valid_sh2_r;
	assign out_wr_en = pipe_en && out_valid;
	assign dout = gs_px_r;

	always_comb
	begin
		rgb_sum = 'h0;
		for ( int i=0; i<3; ++i )
		begin
			rgb_sum += din_r[ i ];
		end
	end

endmodule: grayscale

