
import globals_pkg::SAFE_PX_WIDTH;
import globals_pkg::PX_WIDTH;
import globals_pkg::ROW_IDX_WIDTH;
import globals_pkg::COL_IDX_WIDTH;

module sobel_pipe_out(

	input logic clk, rst,

	input logic in_valid,
	input logic signed [ SAFE_PX_WIDTH-1:0 ] hgrad, vgrad,
	input logic out_full,

	output logic pipe_wr_en,
	output logic out_wr_en,
	output logic [ PX_WIDTH-1:0 ] dout

	output logic done

);

	typedef enum logic [ 2:0 ]
	{
		S_OOB, S_ZERO, S_VALID
	} box_center_state_t;
	box_center_state_t box_center_state, box_center_state_c; 

	logic signed [ PX_WIDTH-1:0 ] grad_abs_mean;

	//
	// track position of CENTER px in box
	//
	logic signed [ ROW_IDX_WIDTH:0 ] irow, irow_c; 
	logic signed [ COL_IDX_WIDTH:0 ] icol, icol_c; 

	always_comb
	begin
		pipe_wr_en = 1'b0;

		grad_abs_mean = 'h0;
		out_wr_en = 1'b0;
		dout = 'h0;

		irow_c = irow;
		icol_c = icol;
		box_center_state_c = box_center_state;

		if ( !out_full )
		begin
			//
			// pipe_wr_en indicates that out stage can consume register
			// contents between compute and it, and they are safe to be
			// overwritten; this corresponds to !out_full.
			//
			pipe_wr_en = 1'b1;

			//
			// if compute stage outputs correspond to gradients
			// driven by a "valid" bottom right px ( even if the 
			// center px is OOB or defaulted to zero ), advance px
			// position
			//
			if ( in_valid )
			begin

				if ( icol === IMG_WIDTH-1 )
				begin
					icol_c = 0;
					irow_c = irow + 1'h1;
				end
				else
				begin
					icol_c = icol + 1'h1;
				end

				case ( box_center_state )
					S_OOB:
					begin
						if ( irow_c === 1'h1 )
						begin
							// next px is on top frame edge
							box_center_state_c = S_ZERO;
						end
					end
					S_ZERO:
					begin
						dout = 'h0; // redundant given default assignment
						out_wr_en = 1'b1;
						if ( icol_c === 1'h1 )
						begin
							// next px is right of left frame edge
							box_center_state_c = S_VALID;
						end
						if ( irow_c === IMG_HEIGHT )
						begin
							// next px is below bottom frame edge
							box_center_state_c = S_OOB;
						end
					end
					S_VALID:
					begin
						grad_abs_mean = (
							( hgrad[ SAFE_PX_WIDTH-1 ] ? -hgrad : hgrad )
							( vgrad[ SAFE_PX_WIDTH-1 ] ? -vgrad : vgrad )
						) >>> 1;
						// saturate
						dout = (
							| ( grad_abs_mean[ SAFE_PX_WIDTH-1:PX_WIDTH ] )
							? ( PX_WIDTH )'hFF
							: grad_abs_mean[ PX_WIDTH-1:0 ]
						);
						out_wr_en = 1'b1;

						if ( icol_c === IMG_WIDTH-1 )
						begin
							// next px is on right frame edge
							box_center_state_c = S_ZERO;
						end
					end
				endcase
			end

		end

	end

	assign done = irow_c > IMG_HEIGHT-1;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			irow <= -1'h1;
			icol <= -1'h1;
			box_center_state <= S_OOB;
		end
		else
		begin
			irow <= irow_c;
			icol <= icol_c;
			box_center_state <= box_center_state_c;
		end
	end

endmodule: sobel_pipe_out

