
import globals_pkg::BYTE_WIDTH;
import globals_pkg::SOBEL_BOX_DIM;

module sobel_pipe_fetch
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

	input  logic [ BYTE_WIDTH-1:0 ] px_in,
	input  logic in_valid, 

	output logic [ 0:SOBEL_BOX_DIM-1 ] [ BYTE_WIDTH-1:0 ] box_right_col_out,
	output logic out_valid
);

	localparam int ROWBUF_ADDR_WIDTH = COL_ID_WIDTH;

	/* Row tags:
	 * Used to index the box's logical top, middle, bottom rows or their
	 * select signals for readability
	 */
	localparam int
		TOP = 0, MIDDLE = 1, BOTTOM = 2;

	/* Match grayscale byte i+1 ( fetched in next cycle if available );
	 * generated from *_id_r */
	logic [ ROW_ID_WIDTH-1:0 ] row_id_next;
	logic [ COL_ID_WIDTH-1:0 ] col_id_next;

	/* Match grayscale byte i ( bottom right sample in box ) being fetched in
 	 * current cycle
	 * *_id_r shall be at most FRAME_{WIDTH, HEIGHT}-1 ( never equal )
	 * col_id_r will be asserted as rowbufs read addr
	 */
	logic [ ROW_ID_WIDTH-1:0 ] row_id_r;
	logic [ COL_ID_WIDTH-1:0 ] col_id_r;
	logic [ 0:SOBEL_BOX_DIM-1 ] [ $clog2( SOBEL_BOX_DIM )-1:0 ] box_rowsels_new;

	/* Match grayscale byte i-1 ( fetched in prev cycle ).
 	 * Box top and bottom are decoded from rowbufs over this cycle
	 */
	logic [ BYTE_WIDTH-1:0 ] px_in_r;
	logic [ COL_ID_WIDTH-1:0 ] col_id_sh_r;
	logic valid_r;
	logic [ 0:SOBEL_BOX_DIM-1 ] [ $clog2( SOBEL_BOX_DIM )-1:0 ] box_rowsels_r;

	/* Match grayscale byte i-2 as box bottom right */
	logic [ 0:SOBEL_BOX_DIM-1 ] [ BYTE_WIDTH-1:0 ] rowbufs_dout_r;
	logic [ BYTE_WIDTH-1:0 ] px_in_sh_r;
	logic valid_sh_r;
	logic [ 0:SOBEL_BOX_DIM-1 ] [ $clog2( SOBEL_BOX_DIM )-1:0 ] box_rowsels_sh_r;
	/* Assembled from rowbufs output and new byte based on box row selects */
	logic [ 0:SOBEL_BOX_DIM-1 ] [ BYTE_WIDTH-1:0 ] box_right_col_new;

	/* Combinational signals for bram access */
	logic [ ROWBUF_ADDR_WIDTH-1:0 ] rowbufs_wr_addr;
	logic [ 0:SOBEL_BOX_DIM-1 ] rowbufs_wr_en;
	logic [ BYTE_WIDTH-1:0 ] rowbufs_din;

	logic [ ROWBUF_ADDR_WIDTH-1:0 ] rowbufs_rd_addr;
	logic rowbufs_rd_en;
	logic [ 0:SOBEL_BOX_DIM-1 ] [ BYTE_WIDTH-1:0 ] rowbufs_dout;

	generate
		/* Each BRAM line caches one row */
		for ( genvar i=0; i<SOBEL_BOX_DIM; ++i )
		begin
			bram #(
				.DWIDTH( BYTE_WIDTH ),
				.ADDR_WIDTH( ROWBUF_ADDR_WIDTH )
			) row_buf (
				.clk  ( clk ),

				.wr_addr( rowbufs_wr_addr ),
				.wr_en  ( rowbufs_wr_en[ i ] ),
				.din    ( rowbufs_din ),

				.rd_addr( rowbufs_rd_addr ),
				.rd_en  ( rowbufs_rd_en ),
				.dout   ( rowbufs_dout[ i ] )
			);
		end

	endgenerate

	always_ff @( posedge clk )
	begin
		if ( rst )
		begin
			row_id_r <= 'h0;
			col_id_r <= 'h0;

			valid_r <= 1'b0;
			/*
			 * Since the row selects are shift-rotated, the order of the
			 * initial values doesn't matter as long as they cover 0, 1, 2
			 */
			box_rowsels_r[ TOP ]    <= 2'h0;
			box_rowsels_r[ MIDDLE ] <= 2'h1;
			box_rowsels_r[ BOTTOM ] <= 2'h2;

			valid_sh_r <= 1'b0;
		end
		else if ( pipe_en )
		begin
			row_id_r <= row_id_next;
			col_id_r <= col_id_next;

			valid_r <= in_valid;
			box_rowsels_r[ TOP:BOTTOM ] <= box_rowsels_new[ TOP:BOTTOM ];

			valid_sh_r <= valid_r;

		end

		if ( pipe_en )
		begin
			px_in_r <= px_in;
			col_id_sh_r <= col_id_r;

			rowbufs_dout_r[ 0:SOBEL_BOX_DIM-1 ] <= rowbufs_dout[ 0:SOBEL_BOX_DIM-1 ];
			px_in_sh_r <= px_in_r;
			box_rowsels_sh_r[ TOP:BOTTOM ] <= box_rowsels_r[ TOP:BOTTOM ];
		end

	end 

	assign out_valid = valid_sh_r;
	assign box_right_col_out = box_right_col_new;

	always_comb
	begin
		col_id_next = col_id_r;
		row_id_next = row_id_r;
		if ( in_valid )
		begin
			col_id_next = col_id_r + 1'h1;
			if ( col_id_r===FRAME_WIDTH-1 )
			begin
				col_id_next = 'h0;
				row_id_next = row_id_r + 1'h1;
				if ( row_id_r === FRAME_HEIGHT-1 )
				begin
					row_id_next = 'h0;
				end
			end
		end

		rowbufs_rd_addr = col_id_r;
		rowbufs_rd_en = pipe_en;
		box_rowsels_new[ TOP:BOTTOM ] = box_rowsels_r[ TOP:BOTTOM ];
		/* in_valid gating prevents multiple shifts for the same row-initial
  		 * byte during bubbles, where col_id_r doesn't increment */
		if ( in_valid && ( col_id_r==='h0 ) )
		begin
			
			box_rowsels_new[ TOP:MIDDLE ] = box_rowsels_r[ MIDDLE:BOTTOM ];
			box_rowsels_new[ BOTTOM ] = box_rowsels_r[ TOP ];
		end

		/*
		 * Write to the buf line storing the box's bottom row. This can be
		 * done in the same cycle as the read addr is being decoded. There is
		 * no race for the buffered bottom-row pixel. In any case, we use the
		 * upstream GS byte directly and ignore rowbuf output for the
		 * box's bottom row.
		 */
		rowbufs_wr_addr = col_id_sh_r;
		rowbufs_wr_en = 'b0;
		if ( valid_r && pipe_en )
		begin
			/*
			 * Only enable write for the buf line currently used as the box's
			 * bottom row
			 */
			rowbufs_wr_en[ box_rowsels_r[ BOTTOM ] ] = 1'b1;
		end
		rowbufs_din = px_in_r;

		/*
		 * There are currently muxes on the output path, but the right col
		 * elements should be registered right away by the next stage
		 */
		box_right_col_new[ TOP ] = rowbufs_dout_r[ box_rowsels_sh_r[ TOP ] ];
		box_right_col_new[ MIDDLE ] = rowbufs_dout_r[ box_rowsels_sh_r[ MIDDLE ] ];
		box_right_col_new[ BOTTOM ] = px_in_sh_r;

	end

endmodule

