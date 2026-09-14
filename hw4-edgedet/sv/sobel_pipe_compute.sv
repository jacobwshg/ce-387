
import globals_pkg::BYTE_WIDTH;
import globals_pkg::SAFE_BYTE_WIDTH;
import globals_pkg::SOBEL_BOX_DIM;
import globals_pkg::sobel_box_t;

import globals_pkg::compute_sobel_hgrad;
import globals_pkg::compute_sobel_vgrad;

module sobel_pipe_compute(

	input logic  clk,
	input logic  rst,
	input logic  pipe_en,

	input logic  [ 0:SOBEL_BOX_DIM-1 ] [ BYTE_WIDTH-1:0 ] box_right_col_in,
	input logic  in_valid,

	output logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad_out,
	output logic signed [ SAFE_BYTE_WIDTH-1:0 ] vgrad_out,
	output logic out_valid
);

	/* Box is indexed in col-major order ( in terms of orig frame ), 
	 * so print [0][0] [1][0] [2][0], [0][1], ... */
	function automatic void
	PRINTBOX( input sobel_box_t box );
		$write( "box: " );
		for ( int i=0; i<SOBEL_BOX_DIM; ++i )
		begin
			for ( int j=0; j<SOBEL_BOX_DIM; ++j )
			begin
				$write( "%2h ", box[ j ][ i ] );
			end
			$write( ", " );
		end
		$display( "" );
	endfunction

	sobel_box_t box_new;

	sobel_box_t box_r;
	logic box_valid_r;
	logic signed [ SAFE_BYTE_WIDTH-1:0 ] sobel_hgrad, sobel_vgrad;

	logic signed [ SAFE_BYTE_WIDTH-1:0 ] sobel_hgrad_r, sobel_vgrad_r;
	logic grads_valid_r;

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			box_valid_r <= 1'b0;

			grads_valid_r <= 1'b0;
		end
		else if ( pipe_en )
		begin
			box_valid_r <= in_valid;

			grads_valid_r <= box_valid_r;
		end

		if ( pipe_en )
		begin
			box_r <= box_new;

			sobel_hgrad_r <= sobel_hgrad;
			sobel_vgrad_r <= sobel_vgrad;
		end
	end

	assign hgrad_out = sobel_hgrad_r;
	assign vgrad_out = sobel_vgrad_r;
	assign out_valid = grads_valid_r;

	always_comb
	begin
		box_new = box_r;
		if ( in_valid )
		begin
			/*
			 * Avoid shifting in same right col more than once
			 * during bubbles
			 */
			box_new[ 0:1 ] = box_r[ 1:2 ];
			box_new[ 2 ]   = box_right_col_in;
		end

		sobel_hgrad = compute_sobel_hgrad( box_r );
		sobel_vgrad = compute_sobel_vgrad( box_r );
	end

endmodule: sobel_pipe_compute

