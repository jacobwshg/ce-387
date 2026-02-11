
module sobel #(
	parameter IMG_WIDTH = 720,
	parameter IMG_HEIGHT = 576,
	parameter IROW_WIDTH = 10,
	parameter ICOL_WIDTH = 10
)
(
	input  logic clk,
	input  logic rst,

	input  logic in_empty,
	input  logic [ 7:0 ] in_dout,
	input  logic out_full,

	output logic in_rd_en,
	output logic out_wr_en,
	output logic [ 7:0 ] out_din
);


	localparam BOX_DIM = 3;

	typedef enum logic [ 2:0 ]
	{
		S_UPDATE_IDX, 
		S_READ, 
		S_WRITE
	} state_t;
	state_t state, state_c;

	/* store box in column-major order */
	logic signed [ BOX_DIM-1:0 ][ BOX_DIM-1:0 ][ 11:0 ] 
		box, box_c; 

	/*
 	 * Track the logical img indices of the bottom right px in the box.
 	 * This is due to the fact that the box proceeds right and down through
 	 * the img, thus the px from upstream fifo must be the bottom
 	 * right one in the next box.
 	 */
	logic [ IROW_WIDTH-1:0 ]
		irow, irow_c;
	logic [ ICOL_WIDTH-1:0 ]
		icol, icol_c;

	logic [ BOX_DIM-1:0 ] rowbuf_we;

	logic [ BOX_DIM-1:0 ] [ 7:0 ] rowbuf_dout;

	logic [ 1:0 ]
		top_row, mid_row, bot_row,
		top_row_c, mid_row_c, bot_row_c;

	/* 
 	 * The bottom right px fetched from upstream fifo (wired from the less
 	 * descriptive in_dout when valid), to be written to rowbuf
 	 */
	logic [ 7:0 ] bot_px_c;

	/*
 	 * Reserve enough bit width for gradient results
 	 */
	logic signed [ 11:0 ] 
		hgrad_c, vgrad_c,
		result_c;

	/*
 	 * Wire rowbuf read addr to the next column idx, which is computed 
 	 * in update state. It will be passed on the clk edge going from 
 	 * update state to read state. Thus, top and middle pxs in the next column 
 	 * will be ready in read state.
 	 *
 	 * Wire write addr to the current column idx. It will be passed on the 
 	 * clk edge going from read state to write state, along with the 
 	 * write-enable for the bottom row line.
 	 *
 	 */
	genvar i;
	generate
		for ( i = 0; i < BOX_DIM; ++i ) 
		begin
			bram #(
				.BRAM_ADDR_WIDTH( ICOL_WIDTH ),
				.BRAM_DATA_WIDTH( 8 )
			) rowbuf (
				.clock  ( clk ),
				.rd_addr( icol_c ),
				.wr_addr( icol ),
				.wr_en  ( rowbuf_we[i] ),
				.dout   ( rowbuf_dout[i] ),
				.din	( bot_px_c )
			);
		end
	endgenerate

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			/*
 			 * Begin in read state, so we can write the initial px from
 			 * upstream fifo to idx 0 in rowbuf's bottom row line. 
 			 * Starting in update state will cause initial write on index 1.
 			 */
			state <= S_READ;
			box   <= 'h0;
			irow  <= 'h0;
			icol  <= 'h0;
			{ top_row, mid_row, bot_row } <= { 2'h0, 2'h1, 2'h2 };
		end
		else
		begin
			state <= state_c;
			box   <= box_c;
			irow  <= irow_c;
			icol  <= icol_c;
			{ top_row, mid_row, bot_row } <= { top_row_c, mid_row_c, bot_row_c };
		end
	end

	always_comb
	begin
		/*
 		 * Compute sobel gradients anytime based on whatever is in the box.
 		 *
 		 * New box values shift in on the clk edge from read state to write
 		 * state. Result stabilizes during the write state cycle, and get
 		 * pushed to downstream fifo on the clk edge going out of write state.
 		 *
 		 */	
		hgrad_c = 
			    - box[0][0]
			+ ( -(box[0][1] << 1) )
			+ ( - box[0][2] )
			+     box[2][0]
			+ (   box[2][1] << 1 )
			+     box[2][2];
		vgrad_c = 
			  - box[0][0]
			+   box[0][2]
			+(-(box[1][0]<<1))
			+(  box[1][2]<<1)
			+(- box[2][0])
			+   box[2][2];

		in_rd_en  = 1'b0;
		out_wr_en = 1'b0;
		out_din   = 8'h0;
		state_c   = state;
		box_c     = box;
		{ irow_c, icol_c } = { irow, icol };

		rowbuf_we = 'h0;
		{ top_row_c, mid_row_c, bot_row_c } = { top_row, mid_row, bot_row };
		bot_px_c  = 8'h0;
		result_c  = 12'h0;

		case (state)
			S_UPDATE_IDX:
			begin
				/*
 				 * Compute index register updates; 
 				 *
 				 * The new combinational indices will be applied at the nearest next clk edge,
 				 * so the clocked values used in read state below will be the same as 
 				 * the combinational ones computed in this state.
 				 */
				icol_c = icol + 1'h1;
				if ( icol_c == IMG_WIDTH )
				begin
					/*
 					 * When reaching end of row, rotate rowbuf line mappings
 					 * such that the current top row can be "shifted out" 
 					 * by having its line overwritten with the new bottom row.
 					 */
					icol_c = 'h0;
					irow_c = irow + 1'h1;
					{ top_row_c, mid_row_c, bot_row_c } = { mid_row, bot_row, top_row };
				end
				state_c = S_READ;
			end

			S_READ:
			begin
				if ( irow >= IMG_HEIGHT )
				begin
					/*
					 * If bottom row idx lies below img, there's nothing to
					 * read from upstream fifo (if we tried to read, we'll get
					 * stuck); jump to write state. In any case, we'll know 
					 * that the box center px is in the img's bottom row and 
					 * simply default to writing zero to downstream fifo.
					 */
					state_c = S_WRITE;
				end
				else if ( ~in_empty )
				begin
					/*
 					 * Construct the column to shift into the box at the next clk
 					 * edge.
 					 * - Top and middle pxs are taken from rowbuf bram.
 					 * - Bottom px is expected from upstream fifo.
 					 *
 					 * Also store a copy of the new bottom px into rowbuf,
 					 * so that it can be read back for use in the next iteration.
 					 *
 					 */
					bot_px_c = in_dout;

					box_c[0] = box[1];
					box_c[1] = box[2];
					box_c[2] =
					{
						12'( rowbuf_dout[ top_row ] ),
						12'( rowbuf_dout[ mid_row ] ),
						12'( bot_px_c )
					};

					rowbuf_we[ bot_row ] = 1'b1;

					in_rd_en = 1'b1;
					state_c = S_WRITE;
				end
			end

			S_WRITE:
			begin
				if ( (irow == 0) | (irow==1 & icol==0) )
				begin
					/*
 					 * Box bottom right indices (0, 0) through (1, 0) 
 					 * corresponds to center px indices (-1, -1) through (0, -1),
 					 * which lie outside of the logical img and should not be
 					 * output to downstream fifo. The operator result is not 
 					 * valid either. Simply return to update state. 
 					 */
					state_c = S_UPDATE_IDX;
				end
				else if ( ~out_full )
				begin
					/*
 					 * - When box bottom row idx equals 1 or IMG_HEIGHT, center px 
 					 *   is on the img's horizontal border and should default to zero.
 					 *
 					 * - When box right col idx equals 0 or 1, center px
 					 *   is on the img's vertical border and should default to
 					 *   zero.
 					 *
 					 * - Else, center px is the valid result of the sobel operator. 
 					 *   Saturate to 255 if necessary, and put to fifo.
 					 *
 					 */
					// take average of absolute gradient values
					result_c = (
						  ( hgrad_c[11] ? -hgrad_c : hgrad_c )
						+ ( vgrad_c[11] ? -vgrad_c : vgrad_c )
					) >> 1;

					if (
						| { ( irow<=1 ), ( irow>=IMG_HEIGHT ), ( icol<=1 ) }
					)
					begin
						out_din = 8'h0;
					end
					else
					begin
						out_din = ( | result_c[ 11:8 ] ) ? 8'hff : result_c[ 7:0 ];
					end
					out_wr_en = 1'b1;
					state_c = S_UPDATE_IDX;
				end
			end

			default:
			begin
				in_rd_en  = 1'b0;
				out_wr_en = 1'b0;
				out_din   = 8'h0;
				state_c   = S_READ;
				box_c     = 'hx;
				irow_c    = 'hx;
				icol_c    = 'hx;
				{ top_row_c, mid_row_c, bot_row_c } = 'hx;
				bot_px_c  = 'hx;
				result_c  = 'hx;
			end

		endcase
	end

endmodule

