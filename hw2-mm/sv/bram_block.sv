
module bram_block 
#(
	parameter BRAM_ADDR_WIDTH = 10,
	parameter BANK_DATA_WIDTH = 8,
	parameter BANK_CNT = 4,
	parameter BRAM_DATA_WIDTH = BANK_DATA_WIDTH * BANK_CNT
) 
(   input  logic clock,
    input  logic [BRAM_ADDR_WIDTH-1:0] rd_addr,
    input  logic [BRAM_ADDR_WIDTH-1:0] wr_addr,
    input  logic [BANK_CNT-1:0] wr_en,
    //input  logic [BRAM_DATA_WIDTH-1:0] din,
    //output logic [BRAM_DATA_WIDTH-1:0] dout
    input  logic [BANK_DATA_WIDTH-1:0] din,
    output logic [BANK_CNT-1:0][BANK_DATA_WIDTH-1:0] dout
);

    bram #(
        .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
        .BRAM_DATA_WIDTH(BANK_DATA_WIDTH)
    ) brams [BANK_CNT-1:0] (
        .clock(clock),
        .rd_addr(rd_addr),
        .wr_addr(wr_addr),
        .wr_en(wr_en),
        .dout(dout),
        .din(din)
    );
/*
    genvar i;
    generate
        for (i=0; i < BRAM_DATA_WIDTH/8; i++) begin
            bram #(
                .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
                .BRAM_DATA_WIDTH(8)
            ) bram_inst (
                .clock(clock),
                .rd_addr(rd_addr),
                .wr_addr(wr_addr),
                .wr_en(wr_en[i]),
                .dout(dout[(i*8)+7 -: 8]),
                .din(din[(i*8)+7 -: 8])
            );    
        end
    endgenerate
*/

endmodule

