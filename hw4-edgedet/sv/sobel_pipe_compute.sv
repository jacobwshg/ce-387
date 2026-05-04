
import globals_pkg :: BYTE_WIDTH;
import globals_pkg :: SAFE_BYTE_WIDTH;
import globals_pkg :: BOX_DIM;
import globals_pkg :: box_t;

module sobel_pipe_compute(

	input logic clk, rst,
	input logic pipe_wr_en,

	input logic in_valid,
	input box_t box,

	output logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad, vgrad,
	output logic out_valid
);

	logic out_valid_c;
	logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad_c, vgrad_c;

	always_comb
	begin
		out_valid_c = 1'b0;

		hgrad_c = 'h0;
		vgrad_c = 'h0;

		if ( pipe_wr_en && in_valid )
		begin
			out_valid_c = 1'b1;

			vgrad_c =
				- box[ 0 ][ 0 ] - ( box[ 1 ][ 0 ]<<<1 ) - ( box[ 2 ][ 0 ] )
				+ box[ 0 ][ 2 ] + ( box[ 1 ][ 2 ]<<<1 ) + ( box[ 2 ][ 2 ] );
			hgrad_c =
				-   box[ 0 ][ 0 ]       +   box[ 2 ][ 0 ]
				- ( box[ 0 ][ 1 ]<<<1 ) + ( box[ 2 ][ 1 ]<<<1 )
				-   box[ 0 ][ 2 ]       +   box[ 2 ][ 2 ];

		end
	end

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			out_valid <= 1'b0;

			hgrad <= 'h0;
			vgrad <= 'h0;
		end
		else
		begin
			out_valid <= out_valid_c;

			hgrad <= hgrad_c;
			vgrad <= vgrad_c;
		end
	end

endmodule: sobel_pipe_compute

