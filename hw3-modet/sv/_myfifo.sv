
module fifo #(
	parameter FIFO_DATA_WIDTH = 32,
	parameter FIFO_BUFFER_SIZE = 1024) 
(
	input  logic reset,
	input  logic wr_clk,
	input  logic wr_en,
	input  logic [FIFO_DATA_WIDTH-1:0] din,
	output logic full,
	input  logic rd_clk,
	input  logic rd_en,
	output logic [FIFO_DATA_WIDTH-1:0] dout,
	output logic empty
);

	/* convert Z/X to 0 */
	function automatic logic [FIFO_DATA_WIDTH-1:0] 
	to01( input logic [FIFO_DATA_WIDTH-1:0] data );
		logic [FIFO_DATA_WIDTH-1:0] result;
		for ( int i=0; i < $bits(data); i++ )
		begin
			case ( data[i] )  
				0: result[i] = 1'b0;
				1: result[i] = 1'b1;
				default: result[i] = 1'b0;
			endcase;
		end;
		return result;
	endfunction

	/* keep overflow bit for full check */
	localparam FIFO_ADDR_WIDTH = $clog2(FIFO_BUFFER_SIZE) + 1;
	logic [FIFO_DATA_WIDTH-1:0] fifo_buf [FIFO_BUFFER_SIZE-1:0];
	logic [FIFO_ADDR_WIDTH-1:0] wr_addr, rd_addr;

	assign empty = ( wr_addr == rd_addr );
	assign full = 
		(wr_addr[FIFO_ADDR_WIDTH-2:0] == rd_addr[FIFO_ADDR_WIDTH-2:0]) 
		&& (wr_addr[FIFO_ADDR_WIDTH-1] != rd_addr[FIFO_ADDR_WIDTH-1]);

	always_ff @ ( posedge wr_clk, posedge reset )
	begin : write_buffer
		if ( reset )
		begin
			wr_addr <= '0;
		end
		else if ( (wr_en == 1'b1) && (full == 1'b0) )
		begin
			fifo_buf[$unsigned(wr_addr[FIFO_ADDR_WIDTH-2:0])] <= din;
			wr_addr <= wr_addr + '1;
		end
	end

	always_ff @ ( posedge rd_clk, posedge reset )
	begin : read_buffer
		if ( reset )
		begin
			rd_addr <= '0;
		end
		else if ( (rd_en == 1'b1) && (empty == 1'b0) )
		begin
			dout <= to01(fifo_buf[$unsigned(rd_addr[FIFO_ADDR_WIDTH-2:0])]);
			rd_addr <= rd_addr + '1;
		end
	end

endmodule

