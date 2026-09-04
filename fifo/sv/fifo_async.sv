
module fifo_writer
#(
	parameter int DWIDTH = 32,
	parameter int ADDR_WIDTH = 4
)(
	input  logic clk,
	input  logic rst,
	// from upstream
	input  logic wr_en,
	input  logic [ DWIDTH-1:0 ] din,
	// from reader
	input  logic [ ADDR_WIDTH:0 ] rd_addr_g,

	// to upstream
	output logic full,
	// to reader
	output logic [ ADDR_WIDTH:0 ] wr_addr_g,
	// to RAM
	output logic [ ADDR_WIDTH-1:0 ] mem_wr_addr,
	output logic [ DWIDTH-1:0 ] mem_din,
	output logic mem_wr_en
);

	logic full_next, full_r;

	logic [ ADDR_WIDTH:0 ] wr_addr_r, wr_addr_next;
	logic [ ADDR_WIDTH:0 ] wr_addr_g_tmp;
	logic [ ADDR_WIDTH:0 ] wr_addr_g_r;

	logic [ 0:1 ] [ ADDR_WIDTH:0 ] sync_rd_addr_g_r;
	logic [ ADDR_WIDTH:0 ] sync_rd_addr_tmp;
	logic [ ADDR_WIDTH:0 ] sync_rd_addr_r;

	togray_comb #(
		.DWIDTH( ADDR_WIDTH+1 )
	) wr_addr_togray (
		.b( wr_addr_r ), .g( wr_addr_g_tmp )
	);

	fromgray_comb #(
		.DWIDTH( ADDR_WIDTH+1 )
	) sync_rd_addr_fromgray (
		.g( sync_rd_addr_g_r[ 1 ] ),
		.b( sync_rd_addr_tmp )
	);

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			full_r <= 1'b0;
			wr_addr_r <= 'h0;
			wr_addr_g_r <= 'b0;

			sync_rd_addr_g_r[ 0:1 ] <= '{ default: 'b0 };
			sync_rd_addr_r <= 'h0;
		end
		else
		begin
			full_r <= full_next;
			wr_addr_r <= wr_addr_next;
			wr_addr_g_r <= wr_addr_g_tmp[ ADDR_WIDTH:0 ];

			sync_rd_addr_g_r[ 0 ] <= rd_addr_g;
			sync_rd_addr_g_r[ 1 ] <= sync_rd_addr_g_r[ 0 ];
			sync_rd_addr_r <= sync_rd_addr_tmp;
		end
	end

	always_comb
	begin
		wr_addr_next = wr_addr_r;
		if ( ( !full_r ) && wr_en )
		begin
			wr_addr_next += 1'h1;
		end

		full_next = (
			wr_addr_next[ ADDR_WIDTH:0 ] ===
			{ ~sync_rd_addr_r[ ADDR_WIDTH ], sync_rd_addr_r[ ADDR_WIDTH-1:0 ] }
		);

	end

	assign full = full_r;
	assign wr_addr_g = wr_addr_g_r;
	assign mem_wr_addr = wr_addr_r[ ADDR_WIDTH-1:0 ];
	assign mem_din = din;
	assign mem_wr_en = ( !full_r ) && wr_en;

endmodule: fifo_writer

module fifo_reader
#(
	parameter int DWIDTH = 32,
	parameter int ADDR_WIDTH = 4
)(
	input  logic clk,
	input  logic rst,
	// from downstream
	input  logic rd_en,
	// from writer
	input  logic [ ADDR_WIDTH:0 ] wr_addr_g,
	// from RAM
	input  logic [ DWIDTH-1:0 ] mem_dout,

	// to downstream,
	output logic empty,
	output logic [ DWIDTH-1:0 ] dout,
	// to writer
	output logic [ ADDR_WIDTH:0 ] rd_addr_g,
	// to RAM
	output logic [ ADDR_WIDTH-1:0 ] mem_rd_addr,
	output logic mem_rd_en
);

	logic empty_next, empty_r;

	logic [ ADDR_WIDTH:0 ] rd_addr_r, rd_addr_next;
	logic [ ADDR_WIDTH:0 ] rd_addr_g_tmp;
	logic [ ADDR_WIDTH:0 ] rd_addr_g_r;

	logic [ 0:1 ] [ ADDR_WIDTH:0 ] sync_wr_addr_g_r;
	logic [ ADDR_WIDTH:0 ] sync_wr_addr_tmp;
	logic [ ADDR_WIDTH:0 ] sync_wr_addr_r;

	togray_comb #(
		.DWIDTH( ADDR_WIDTH+1 )
	) rd_addr_togray (
		.b( rd_addr_r ), .g( rd_addr_g_tmp )
	);

	fromgray_comb #(
		.DWIDTH( ADDR_WIDTH+1 )
	) sync_wr_addr_fromgray (
		.g( sync_wr_addr_g_r[ 1 ] ),
		.b( sync_wr_addr_tmp )
	);

	always_ff @( posedge clk )
	begin
		if ( rst )
		begin
			empty_r <= 1'b1;
			rd_addr_r <= 'h0;
			rd_addr_g_r <= 'b0;

			sync_wr_addr_g_r[ 0:1 ] <= '{ default: 'b0 };
			sync_wr_addr_r <= 'h0;
		end
		else
		begin
			empty_r <= empty_next;
			rd_addr_r <= rd_addr_next;
			rd_addr_g_r <= rd_addr_g_tmp[ ADDR_WIDTH:0 ];

			sync_wr_addr_g_r[ 0 ] <= wr_addr_g;
			sync_wr_addr_g_r[ 1 ] <= sync_wr_addr_g_r[ 0 ];
			sync_wr_addr_r <= sync_wr_addr_tmp;
		end
	end

	always_comb
	begin
		rd_addr_next = rd_addr_r;
		if ( ( !empty_r ) && rd_en )
		begin
			rd_addr_next += 1'h1;
		end

		empty_next = ( rd_addr_next === sync_wr_addr_r );
	end

	assign empty = empty_r;
	assign dout = mem_dout;
	assign rd_addr_g = rd_addr_g_r;
	assign mem_rd_addr = rd_addr_next[ ADDR_WIDTH-1:0 ];
	// whether to let BRAM clock read addr
	assign mem_rd_en = 1'b1;

endmodule: fifo_reader

module fifo #(
	parameter int DWIDTH = 32,
	parameter int DEPTH = 256
)
(
	input  logic wr_clk,
	input  logic wr_rst,
	input  logic wr_en,
	input  logic [ DWIDTH-1:0 ] din,
	output logic full,

	input  logic rd_clk,
	input  logic rd_rst,
	input  logic rd_en,
	output logic [ DWIDTH-1:0 ] dout,
	output logic empty
);

	function automatic logic [ DWIDTH-1:0 ] to01(
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

	logic [ ADDR_WIDTH:0 ] wr_addr_g, rd_addr_g;

	logic [ ADDR_WIDTH-1:0 ] mem_wr_addr, mem_rd_addr;
	logic mem_wr_en, mem_rd_en;
	logic [ DWIDTH-1:0 ] mem_din, mem_dout;

	bram
	#(
		.DWIDTH( DWIDTH ),
		.ADDR_WIDTH( ADDR_WIDTH )
	) mem (
		.wr_clk( wr_clk ), .wr_addr( mem_wr_addr ),
		.wr_en( mem_wr_en ), .din( mem_din ),

		.rd_clk( rd_clk ), .rd_addr( mem_rd_addr ),
		.rd_en( mem_rd_en ), .dout( mem_dout )
	);

	fifo_writer
	#(
		.DWIDTH( DWIDTH ),
		.ADDR_WIDTH( ADDR_WIDTH )
	) writer (
		.clk( wr_clk ), .rst( wr_rst ),
		.wr_en( wr_en ), .din( din ),
		.rd_addr_g( rd_addr_g ),

		.full( full ),
		.wr_addr_g( wr_addr_g ),
		.mem_wr_addr( mem_wr_addr ), .mem_din( mem_din ), .mem_wr_en( mem_wr_en )
	);

	fifo_reader
	#(
		.DWIDTH( DWIDTH ),
		.ADDR_WIDTH( ADDR_WIDTH )
	) reader (
		.clk( rd_clk ), .rst( rd_rst ),
		.rd_en( rd_en ),
		.wr_addr_g( wr_addr_g ),
		.mem_dout( mem_dout ),

		.empty( empty ), .dout( dout ),
		.rd_addr_g( rd_addr_g ),
		.mem_rd_addr( mem_rd_addr ), .mem_rd_en( mem_rd_en )
	);

endmodule: fifo

