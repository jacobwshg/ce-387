
import globals_pkg::BYTE_WIDTH;
import globals_pkg::SAFE_BYTE_WIDTH;

module sobel_pipe_output
#(
	parameter int FRAME_WIDTH  = 720,
	parameter int FRAME_HEIGHT = 540,
	parameter int COL_ID_WIDTH = $clog2( FRAME_WIDTH ),
	parameter int ROW_ID_WIDTH = $clog2( FRAME_HEIGHT )
)
(
	input  logic clk,
	input  logic rst,
	input  logic pipe_en,

	input  logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad_in,
	input  logic signed [ SAFE_BYTE_WIDTH-1:0 ] vgrad_in,
	input  logic in_valid,

	output logic [ BYTE_WIDTH-1:0 ] px_out,
	output logic out_valid

);

	typedef enum logic [ 2:0 ]
	{
		S_OOB, S_ZERO, S_VALID
	} box_center_state_t;

	/* compute ( | hgrad | + | vgrad | ) / 2 */
	function automatic logic signed [ SAFE_BYTE_WIDTH-1:0 ]
	compute_grads_absmean(
		input logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad,
		input logic signed [ SAFE_BYTE_WIDTH-1:0 ] vgrad
	);
		logic signed [ SAFE_BYTE_WIDTH-1:0 ] grads_absmean = 'h0;
		grads_absmean = (
			( hgrad[ SAFE_BYTE_WIDTH-1 ] ? -hgrad : hgrad ) 
			+ ( vgrad[ SAFE_BYTE_WIDTH-1 ] ? -vgrad : vgrad )
		) >>> 1;
		return grads_absmean;
	endfunction

	/*
	 * Track position of CENTER px in box
	 */
	logic signed [ ROW_ID_WIDTH:0 ] row_id_next;
	logic signed [ COL_ID_WIDTH:0 ] col_id_next;

	logic signed [ ROW_ID_WIDTH:0 ] row_id_r; 
	logic signed [ COL_ID_WIDTH:0 ] col_id_r; 
	logic signed [ SAFE_BYTE_WIDTH-1:0 ] grads_absmean;
	box_center_state_t box_center_state; 

	logic signed [ SAFE_BYTE_WIDTH-1:0 ] grads_absmean_r;
	box_center_state_t box_center_state_r; 
	logic in_valid_r;
	logic [ BYTE_WIDTH-1:0 ] sobel_px;
	logic px_valid;

	logic [ BYTE_WIDTH-1:0 ] sobel_px_r;
	logic px_valid_r;
	
	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			row_id_r <= -1;
			col_id_r <= -1;

			box_center_state_r <= S_OOB;
			in_valid_r <= 1'b0;

			px_valid_r <= 1'b0;
		end
		else if ( pipe_en )
		begin
			row_id_r <= row_id_next;
			col_id_r <= col_id_next;

			box_center_state_r <= box_center_state;
			in_valid_r <= in_valid;

			px_valid_r <= px_valid;
		end

		if ( pipe_en )
		begin
			grads_absmean_r <= grads_absmean;
			sobel_px_r <= sobel_px;
		end

	end

	assign px_out = sobel_px_r;
	assign out_valid = px_valid_r;

	always_comb
	begin: next_state_proc
		box_center_state = box_center_state_r;

		case ( box_center_state_r )
			S_OOB:
			begin
				if ( row_id_r === 'h0 )
				begin
					box_center_state = S_ZERO;
				end
			end
			S_ZERO:
			begin
				if ( row_id_r === 'h0 || row_id_r === FRAME_HEIGHT-1 )
				begin
					// next px is on top or bottom frame edge
					box_center_state = S_ZERO;
				end
				else if ( col_id_r === 1'h1 )
				begin
					// next px is right of left frame edge
					box_center_state = S_VALID;
				end
			end
			S_VALID:
			begin
				if ( col_id_r === FRAME_WIDTH-1 )
				begin
					// next px is on right frame edge
					box_center_state = S_ZERO;
				end
			end
			default:
			begin
				box_center_state = S_OOB;
			end
		endcase
	end: next_state_proc

	always_comb
	begin
		row_id_next = row_id_r;
		col_id_next = col_id_r;
		if ( in_valid )
		begin
			/* If compute stage outputs correspond to gradients
			 * driven by a "valid" bottom right px ( even if the 
			 * center px is OOB or defaulted to zero ), advance px
			 * position */
			col_id_next = col_id_r + 1'h1;
			if ( col_id_r === FRAME_WIDTH-1 )
			begin
				col_id_next = 'h0;
				row_id_next = row_id_r + 1'h1;
				if ( row_id_r === FRAME_HEIGHT-1 )
				begin
					/* wrap to next frame */
					row_id_next = 'h0;
				end
			end
		end

		grads_absmean = compute_grads_absmean( hgrad_in, vgrad_in );

		sobel_px = 'h0;
		px_valid = 1'b0;
		case ( box_center_state_r )
			S_OOB:
			begin
			end
			S_ZERO:
			begin
				px_valid = in_valid_r;
			end
			S_VALID:
			begin
				sobel_px = grads_absmean_r[ BYTE_WIDTH-1:0 ];
				if ( |grads_absmean_r[ SAFE_BYTE_WIDTH-1:BYTE_WIDTH ] )
				begin
					/* saturate */
					sobel_px = 8'hFF;
				end
				px_valid = in_valid_r;
			end
			default:
			begin
			end
		endcase
	end

endmodule: sobel_pipe_output

