`timescale 1ns/1ps

import globals_pkg::*;
import quant_pkg::*;

module multiply (
    input  logic               clk,
    input  logic               rst,

    input  logic signed [31:0] x_in,
    input  logic               x_in_empty,
    output logic               x_in_rd_en,

    input  logic signed [31:0] y_in,
    input  logic               y_in_empty,
    output logic               y_in_rd_en,

    output logic signed [31:0] y_out,
    input  logic               y_out_full,
    output logic               y_out_wr_en
);

    logic signed [31:0] x_r, y_r;
    logic vld1;
    
    logic signed [31:0] prod_r;
    logic vld2;

    logic signed [31:0] out_r;
    logic vld3;

    wire rdy3 = ~vld3 | ~y_out_full;
    wire rdy2 = ~vld2 | rdy3;
    wire rdy1 = ~vld1 | rdy2;

    assign x_in_rd_en = ~x_in_empty & ~y_in_empty & rdy1;
    assign y_in_rd_en = x_in_rd_en;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            x_r <= '0;
            y_r <= '0;
            vld1 <= 1'b0;

            prod_r <= '0;
            vld2 <= 1'b0;

            out_r <= '0;
            vld3 <= 1'b0;
        end else begin
            if (x_in_rd_en) begin
                x_r <= x_in;
                y_r <= y_in;
                vld1 <= 1'b1;
            end else if (rdy2) begin
                vld1 <= 1'b0;
            end

            if (vld1 && rdy2) begin
                prod_r <= x_r * y_r;
                vld2 <= 1'b1;
            end else if (rdy3) begin
                vld2 <= 1'b0;
            end

            if (vld2 && rdy3) begin
                out_r <= DEQUANT(prod_r);
                vld3 <= 1'b1;
            end else if (~y_out_full) begin
                vld3 <= 1'b0;
            end
        end
    end

    assign y_out = out_r;
    assign y_out_wr_en = vld3;

endmodule