
module bram 
#(
	parameter int DWIDTH = 32,
	parameter int ADDR_WIDTH = 10
) 
(
	input  logic wr_clk,
	input  logic [ ADDR_WIDTH-1:0 ] wr_addr,
	input  logic wr_en,
	input  logic [ DWIDTH-1:0 ] din, 

	input  logic rd_clk,
	input  logic [ ADDR_WIDTH-1:0 ] rd_addr,
	input  logic rd_en,
	output logic [ DWIDTH-1:0 ] dout

);

	logic [ DWIDTH-1:0 ] mem [ 2**ADDR_WIDTH-1:0 ];
	logic [ ADDR_WIDTH-1:0 ] rd_addr_r;
	
	always_ff @( posedge rd_clk )
	begin
		if ( rd_en )
		begin
			rd_addr_r <= rd_addr;
		end
	end

	always_ff @( posedge wr_clk )
	begin
		if ( wr_en )
		begin
			mem[ wr_addr ] <= din;
		end
	end

	assign dout = mem[ rd_addr_r ];

endmodule: bram

