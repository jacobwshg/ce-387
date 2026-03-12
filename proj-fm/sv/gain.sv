import globals_pkg::*;
import quant_pkg::*;

module gain #(
	parameter int DWIDTH = 32,
	parameter int GAIN_VAL = 1,
	parameter int BITS = 10
)(
	input logic clk,
	input logic rst,

	input logic signed [ DWIDTH-1:0 ] x_in,
	input logic x_in_empty,
	output logic x_in_rd_en,

	output logic signed [ DWIDTH-1:0 ] y_out,
	input logic y_out_full,
	output logic y_out_wr_en
);

	logic valid;

    assign valid = ~x_in_empty & ~y_out_full;
    assign x_in_rd_en = valid;
    assign y_out_wr_en = valid;
    assign y_out = DEQUANT( x_in * GAIN_VAL ) <<< ( 14 - BITS );

endmodule: gain