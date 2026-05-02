
module fifo #(
	parameter FIFO_DATA_WIDTH = 32,
	parameter FIFO_BUFFER_SIZE = 64
) 
(
	input  logic reset,
	input  logic wr_clk,
	input  logic wr_en,
	input  logic [ FIFO_DATA_WIDTH-1:0 ] din,
	output logic full,
	input  logic rd_clk,
	input  logic rd_en,
	output logic [ FIFO_DATA_WIDTH-1:0 ] dout,
	output logic empty
);

	function automatic logic [ FIFO_DATA_WIDTH-1:0 ]
		to01( input logic [ FIFO_DATA_WIDTH-1:0 ] data
	);
		logic [ FIFO_DATA_WIDTH-1:0 ] result;
		for ( int i=0; i<FIFO_DATA_WIDTH; ++i )
		begin
			result[ i ] = ( data[ i ]===1'b1 ) ? 1'b1 : 1'b0;
		end;
		return result;
	endfunction

	localparam FIFO_ADDR_WIDTH = $clog2( FIFO_BUFFER_SIZE );
	logic [ FIFO_DATA_WIDTH-1:0 ] fifo_buf [ FIFO_BUFFER_SIZE-1:0 ];
	logic [ FIFO_ADDR_WIDTH:0 ] wr_addr, wr_addr_c;
	logic [ FIFO_ADDR_WIDTH:0 ] rd_addr, rd_addr_c;
	logic full_c, empty_c;

	assign empty_c = 1'( wr_addr === rd_addr );
	assign full_c = 1'( wr_addr === { ~rd_addr[ FIFO_ADDR_WIDTH ], rd_addr[ FIFO_ADDR_WIDTH-1:0 ] } );
	assign full = full_c;

	assign rd_addr_c = rd_addr + 1'( rd_en && !empty_c );
	assign wr_addr_c = wr_addr + 1'( wr_en && !full_c );

	always_ff @ ( posedge wr_clk )
	begin: write
		if ( wr_en && !full_c )
		begin
			fifo_buf[ wr_addr[ FIFO_ADDR_WIDTH-1:0 ] ] <= din;
		end
	end: write

	always_ff @ ( posedge wr_clk, posedge reset ) 
	begin: update_wr_addr
		if ( reset ) 
			wr_addr <= 'h0;
		else
			wr_addr <= wr_addr_c;
	end: update_wr_addr

	always_ff @ ( posedge rd_clk ) 
	begin: read
		dout <= to01( fifo_buf[ rd_addr_c[ FIFO_ADDR_WIDTH-1:0 ] ] );
	end: read

	always_ff @ ( posedge rd_clk, posedge reset )
	begin: update_rd_addr
		if ( reset ) 
			rd_addr <= 'h0;
		else
			rd_addr <= rd_addr_c;
	end: update_rd_addr

	always_ff @ ( posedge rd_clk, posedge reset )
	begin: update_empty
		if ( reset )
			empty <= 1'b1;
		else
			empty <= 1'( wr_addr == rd_addr_c );
	end: update_empty

endmodule: fifo

