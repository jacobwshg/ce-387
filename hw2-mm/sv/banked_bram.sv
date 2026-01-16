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
	input  logic we,
	input  logic [ DATA_WIDTH-1 : 0 ] din,
	input  logic [ BANK_ID_WIDTH-1 : 0 ] bank_w_id,
	input  logic [ BANK_ADDR_WIDTH-1 : 0 ] bank_w_addr,
	input  logic [ BANK_ADDR_WIDTH-1 : 0 ] bank_r_addr,
	output logic [ BANK_CNT-1 : 0 ] [ DATA_WIDTH-1 : 0 ] dout
);
	(* rom_style = "block" *) 
	logic [BANK_CNT-1:0] [BANK_SIZE-1:0] [DATA_WIDTH-1:0] mem;

	always_ff @ ( posedge clock )
	begin
    	for (int i = 0; i < BANK_CNT; i++)
		begin
        	dout[i] <= mem[i][bank_r_addr];
        	if (we && (i == bank_w_id))
			begin
            	mem[i][bank_w_addr] <= din;
			end
    	end
	end

endmodule

