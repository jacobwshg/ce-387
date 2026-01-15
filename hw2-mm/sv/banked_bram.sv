/*
 * Banked BRAM for parallel read from LHS matrices (X and Y)
 */
module banked_bram
#(
	parameter DATA_WIDTH      = 8,
	parameter BANK_ID_WIDTH   = 3,
	parameter BANK_CNT        = 2**BANK_ID_WIDTH,
	parameter BANK_ADDR_WIDTH = 3,
	parameter BANK_SIZE       = 2**BANK_ADDR_WIDTH
) 
(
	input  logic clock,
	/* 
 	 * For writing (loading) - write to one address in a specific bank each
 	 * time.
	 * For reading - if each bank stores a column, then read the same row; 
	 * if each bank stores a row, then read the same column.
 	 */
	input  logic we;
	input  logic [ DATA_WIDTH-1 : 0 ] din,
	input  logic [ BANK_ID_WIDTH-1 : 0 ] bank_w_id,
	input  logic [ BANK_ADDR_WIDTH-1 : 0 ] bank_w_addr,
	input  logic [ BANK_ADDR_WIDTH-1 : 0 ] bank_r_addr,
	output logic [ BANK_CNT ] [ DATA_WIDTH-1 : 0 ] dout
);
	logic [ BANK_CNT ] bank_we;
	foreach ( bank_we[i] )
	begin
		assign bank_we[i] = we && ( i == bank_w_id );
	end

	bram #(
		.BRAM_ADDR_WIDTH( BANK_ADDR_WIDTH ),
		.BRAM_DATA_WIDTH( DATA_WIDTH )
	) banks [ BANK_CNT ] (
		.clock( clock ),
		.rd_addr( bank_r_addr ),
		.wr_addr( bank_w_addr ),
		.wr_en( bank_we ),
		.din( din ),
		.dout( dout )
	); 
endmodule

