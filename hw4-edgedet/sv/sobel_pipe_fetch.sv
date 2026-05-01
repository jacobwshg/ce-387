
import globals_pkg :: IMG_WIDTH;
import globals_pkg :: IMG_HEIGHT;
import globals_pkg :: COL_IDX_WIDTH;
import globals_pkg :: ROW_IDX_WIDTH;
import globals_pkg :: PX_WIDTH;
import globals_pkg :: BOX_DIM;

module sobel_pipe_fetch(

	input logic clk, rst,
	input logic pipe_wr_en,

	input logic in_empty, 
	input logic [ PX_WIDTH-1:0 ] din,

	// to fifo
	output logic in_rd_en,
	// to next stage
	output logic [ PX_WIDTH-1:0 ] box [ BOX_DIM-1:0 ] [ BOX_DIM-1:0 ],
	output logic out_valid
);

	logic out_valid_c;

	//
	// track position of BOTTOM RIGHT px in box
	//
	logic [ ROW_IDX_WIDTH:0 ] irow, irow_c;
	logic [ COL_IDX_WIDTH:0 ] icol, icol_c;

	logic [ $clog2( BOX_DIM )-1:0 ]
		top_row, mid_row, bot_row,
		top_row_c, mid_row_c, bot_row_c;
	
	logic [ PX_WIDTH-1:0 ] box_c [ BOX_DIM-1:0 ] [ BOX_DIM-1:0 ];

	//
	// combinational signals for bram access
	//
	logic [ COL_IDX_WIDTH:0 ] buf_rd_addr, buf_wr_addr;
	logic buf_wr_en [ 0:BOX_DIM-1 ];
	logic [ PX_WIDTH-1:0 ] buf_dout [ 0:BOX_DIM-1 ];
	logic [ PX_WIDTH-1:0 ] buf_din;

	generate
		//
		// each bram line stores a row
		//
		for ( genvar i=0; i<BOX_DIM; ++i )
		begin
			bram #(
				.BRAM_ADDR_WIDTH( COL_IDX_WIDTH ),
				.BRAM_DATA_WIDTH( PX_WIDTH )
			) rowbuf (
				.clock  ( clk ),
				.rd_addr( buf_rd_addr[ COL_IDX_WIDTH-1:0 ] ),
				.wr_addr( buf_wr_addr[ COL_IDX_WIDTH-1:0 ] ),
				.wr_en  ( buf_wr_en[ i ] ),
				.dout   ( buf_dout [ i ] ),
				.din    ( buf_din )
			);
		end

	endgenerate
	
	always_comb
	begin
		//
		// bottom row buf's [ icol ] will be written to at the end of this
		// cycle
		// bottom row buf's [ icol_c ] will be read from at the end of this
		// cycLe
		//
		// icol_c has two purposes: cur rd addr, and next wr addr.
		//

		//
		// pipe_wr_en should be decoupled from in_emptU
		// if in_empty && !out_full, still enabKe pipe write
		//		

		out_valid_c = 1'b0;
		in_rd_en = 1'b0;

		icol_c = icol;
		irow_c = irow;
		{ top_row_c, mid_row_c, bot_row_c } = { top_row, mid_row, bot_row };
		box_c = box;

		buf_rd_addr = icol;
		buf_wr_addr = icol;
		buf_wr_en = '{ default: 'b0 };
		buf_din = 'h0;

		//
		// if !in_empty, don't be in a hurry to get the next element yet;
		// if downstream is full, we will lose an element
		//
		// if downstream gives fetch stage green light, then get a bottom-row element from fifo, 
		// and read top row and bottom row elements from buf to match this element
		//
		//  when bottom row idx falls below frame bottom edge, still assert
		//  "valid" to allow downstream to write the zero bottom edge
		//
		if ( pipe_wr_en && ( irow_c>IMG_HEIGHT-1 || !in_empty ) )
		begin

			out_valid_c = 1'b1;

			if ( icol === IMG_WIDTH-1 )
			begin
				//
				// the element read in at the start of this cycle is on the
				// img right edge. in the next cycle, we should read from the left
				// edge.
				//
				icol_c = 'h0;
				irow_c = irow + 1'h1;
				{ top_row_c, mid_row_c, bot_row_c } = { mid_row, bot_row, top_row };
			end
			else
			begin
				icol_c = icol + 1'h1;
			end

			//
			// if bottom right px is still in frame, the corresponding fifo
			// elem is valid; update box and buffer
			//
			if ( irow_c < IMG_HEIGHT )
			begin
				in_rd_en = 1'b1;

				box_c[ 0 ] = box[ 1 ];
				box_c[ 1 ] = box[ 2 ];
				box_c[ 2 ] = '{ buf_dout[ top_row ], buf_dout[ mid_row ], din };

				buf_rd_addr = icol_c;
				// buf_wr_addr doesn't change, always write to current col
				buf_wr_en[ bot_row ] = 1'b1;
				buf_din = din;

			end
		end

	end

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			out_valid <= 1'b0;

			icol <= 'h0;
			irow <= 'h0;

			{ top_row, mid_row, bot_row } <= '{ default: 'h0 };
			box <= '{ default: 'h0 };
		end
		else
		begin
			out_valid <= out_valid_c;

			icol <= icol_c;
			irow <= irow_c;

			{ top_row, mid_row, bot_row } = { top_row_c, mid_row_c, bot_row_c };
			box <= box_c;
		end

	end

endmodule

