import globals_pkg::*;
import quant_pkg::*;

module sub #(
	parameter int DWIDTH = 32
)(
	input logic clk,
	input logic rst,

	input logic signed [ DWIDTH-1:0 ] x_in,
	input logic x_in_empty,
	output logic x_in_rd_en,

	input logic signed [ DWIDTH-1:0 ] y_in,
	input logic y_in_empty,
	output logic y_in_rd_en,

	output logic signed [ DWIDTH-1:0 ] y_out,
	input logic y_out_full,
	output logic y_out_wr_en
);

	logic valid;

    assign valid = ~x_in_empty & ~y_in_empty & ~y_out_full;
    assign x_in_rd_en = valid;
    assign y_in_rd_en = valid;
    assign y_out_wr_en = valid;
    assign y_out = x_in - y_in;


endmodule: sub