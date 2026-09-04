
module fifo #(
	parameter int DWIDTH = 32,
	parameter int DEPTH = 16
)
(
	input  logic clk,
	input  logic rst,

	input  logic wr_en,
	input  logic [ DWIDTH-1:0 ] din,
	output logic full,

	input  logic rd_en,
	output logic [ DWIDTH-1:0 ] dout,
	output logic empty
);

	function automatic logic [ DWIDTH-1:0 ]
	to01(
		input logic [ DWIDTH-1:0 ] data
	);
		logic [ DWIDTH-1:0 ] result;
		for ( int i=0; i < DWIDTH; ++i )
		begin
			result[ i ] = ( data[ i ] === 1'b1 ) ? 1'b1 : 1'b0;
		end;
		return result;
	endfunction


	localparam int ADDR_WIDTH = $clog2( DEPTH );
	logic [ DWIDTH-1:0 ] mem [ DEPTH-1:0 ];

	logic [ ADDR_WIDTH:0 ] wr_addr_r, wr_addr_next;
	logic [ ADDR_WIDTH:0 ] rd_addr_r, rd_addr_next;
	logic full_next, full_r;
	logic empty_next, empty_r;

	always_ff @ ( posedge clk )
	begin: wr_meta_proc
		if ( rst )
		begin
			wr_addr_r <= 'h0;
			full_r <= 1'b0;
		end
		else
		begin
			wr_addr_r <= wr_addr_next;
			full_r <= full_next;
		end
	end: wr_meta_proc

	always_ff @ ( posedge clk )
	begin: wr_proc
		if ( !full_r && wr_en )
		begin
			mem[ wr_addr_r[ ADDR_WIDTH-1:0 ] ] <= din;
		end
	end: wr_proc

	assign wr_addr_next = wr_addr_r + ( ( !full_r && wr_en ) ? 1'h1 : 1'h0 );
	assign full_next = (
		wr_addr_next[ ADDR_WIDTH:0 ] ===
		{ ~rd_addr_r[ ADDR_WIDTH ], rd_addr_r[ ADDR_WIDTH-1:0 ] }
	);

	assign full = full_r;

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			rd_addr_r <= 'h0;
			empty_r <= 1'b1;
		end
		else
		begin
			rd_addr_r <= rd_addr_next;
			empty_r <= empty_next; 
		end
	end

	assign rd_addr_next = rd_addr_r + ( ( !empty_r && rd_en ) ? 1'h1 : 1'h0 );
	assign empty_next = ( rd_addr_next === wr_addr_r );

	assign dout = mem[ rd_addr_r[ ADDR_WIDTH-1:0 ] ];
	assign empty = empty_r;

endmodule

