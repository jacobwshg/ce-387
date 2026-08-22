
module bram 
#(
	parameter int DWIDTH = 32,
	parameter int ADDR_WIDTH = 10
) 
(
	input  logic clk,
	input  logic [ ADDR_WIDTH-1:0 ] wr_addr,
	input  logic [ ADDR_WIDTH-1:0 ] rd_addr,
	input  logic wr_en,
	input  logic rd_en,
	input  logic [ DWIDTH-1:0 ] din, 
	output logic [ DWIDTH-1:0 ] dout
);

	logic [ DWIDTH-1:0 ] mem [ 2**ADDR_WIDTH-1:0 ];
	logic [ ADDR_WIDTH-1:0 ] rd_addr_r;
	
	always_ff @( posedge clk )
	begin
		if ( rd_en ) rd_addr_r <= rd_addr;
		if ( wr_en ) mem[ wr_addr ] <= din; 
	end

	assign dout = mem[ rd_addr_r ];

endmodule: bram

