
module fifo #(
	parameter FIFO_DATA_WIDTH = 32,
	parameter FIFO_BUFFER_SIZE = 256
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

	function automatic logic [ FIFO_DATA_WIDTH-1:0 ] to01(
		input logic [ FIFO_DATA_WIDTH-1:0 ] data
	);
		logic [ FIFO_DATA_WIDTH-1:0 ] result;
		for ( int i=0; i < FIFO_DATA_WIDTH; ++i )
		begin
			result[ i ] = ( data[ i ] === 1'b1 ) ? 1'b1 : 1'b0;
		end;
		return result;
	endfunction

	localparam FIFO_ADDR_WIDTH = $clog2( FIFO_BUFFER_SIZE );
	logic [ FIFO_DATA_WIDTH-1:0 ] fifo_buf [ FIFO_BUFFER_SIZE-1:0 ];
	logic [ FIFO_ADDR_WIDTH:0 ] wr_addr;
	logic [ FIFO_ADDR_WIDTH:0 ] rd_addr;

	logic addr_eq, wrap_eq;

	assign addr_eq = wr_addr[ FIFO_ADDR_WIDTH-1:0 ] === rd_addr[ FIFO_ADDR_WIDTH-1:0 ];
	assign wrap_eq = wr_addr[ FIFO_ADDR_WIDTH ] === rd_addr[ FIFO_ADDR_WIDTH ];
	assign full  = addr_eq && !wrap_eq;
	assign empty = addr_eq && wrap_eq;

	always_ff @ ( posedge wr_clk, posedge reset )
	begin
		if ( reset )
		begin
			wr_addr <= 'h0;
		end
		else if ( !full && wr_en )
		begin
			fifo_buf[ wr_addr[ FIFO_ADDR_WIDTH-1:0 ] ] <= din;
			wr_addr <= wr_addr + 1'h1;
		end
	end

	always_ff @ ( posedge rd_clk, posedge reset )
	begin
		if ( reset )
		begin
			rd_addr <= 'h0;
			dout <= 'hDEADBEEF;
		end
		else if ( !empty )
		begin
			dout <= to01( fifo_buf[ rd_addr[ FIFO_ADDR_WIDTH-1:0 ] ] );
			if ( rd_en ) rd_addr <= rd_addr + 1'h1;
		end
	end

endmodule

