`timescale 1ns/1ps

import globals_pkg::*;
import quant_pkg::*;

module iir #(
    parameter int DWIDTH = 32,
    parameter int TAPS = 32,
    parameter int DECIM = 8,
    parameter logic signed [ DWIDTH-1:0 ] X_COEFS [ 0:TAPS-1 ] = '{default:0},
    parameter logic signed [ DWIDTH-1:0 ] Y_COEFS [ 0:TAPS-1 ] = '{default:0}
)(
    input logic clk,
    input logic rst,

    input logic signed [ DWIDTH-1:0 ] x_in,
    input logic x_in_empty,
    input logic y_out_full,

    output logic signed [ DWIDTH-1:0 ] y_out,
    output logic x_in_rd_en,
    output logic y_out_wr_en
);

    typedef enum logic [1:0] { S_WAIT, S_MULT, S_ADD } state_t;
    state_t state, state_c;

    logic signed [ DWIDTH-1:0 ] x_sh [ 0:TAPS-1 ];
    logic signed [ DWIDTH-1:0 ] y_sh [ 0:TAPS-1 ];

    logic signed [ DWIDTH-1:0 ] x_prods [ 0:TAPS-1 ];
    logic signed [ DWIDTH-1:0 ] y_prods [ 0:TAPS-1 ];

    logic [ $clog2(DECIM):0 ] dec_idx, dec_idx_c;
    logic full_dec;

    logic signed [ DWIDTH-1:0 ] current_sum;

    always_comb begin
        current_sum = 'sh0;
        for (int i=0; i<TAPS; ++i) begin
            current_sum += x_prods[i] + y_prods[i];
        end

        y_out = (TAPS == 1) ? current_sum : y_sh[ TAPS-2 ];

        state_c = state;
        x_in_rd_en = 1'b0;
        y_out_wr_en = 1'b0;
        dec_idx_c = dec_idx;

        full_dec = (dec_idx == DECIM);

        case (state)
            S_WAIT: begin
                if (~x_in_empty && (!full_dec || ~y_out_full)) begin
                    x_in_rd_en = 1'b1;
                    if (full_dec) dec_idx_c = 1'h1;
                    else          dec_idx_c = dec_idx + 1'h1;
                    state_c = S_MULT;
                end
            end

            S_MULT: begin
                state_c = S_ADD;
            end

            S_ADD: begin
                if (full_dec) begin
                    y_out_wr_en = 1'b1;
                end
                state_c = S_WAIT;
            end
            
            default: state_c = S_WAIT;
        endcase
    end

    always_ff @ (posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_WAIT;
            dec_idx <= 'h0;
            x_sh <= '{ default: 'sh0 };
            y_sh <= '{ default: 'sh0 };
            x_prods <= '{ default: 'sh0 };
            y_prods <= '{ default: 'sh0 };
        end else begin
            state <= state_c;
            dec_idx <= dec_idx_c;

            if (state == S_WAIT && state_c == S_MULT) begin
                for (int i = TAPS-1; i > 0; i--) x_sh[i] <= x_sh[i-1];
                x_sh[0] <= x_in;
            end

            if (state == S_MULT) begin
                for (int i=0; i<TAPS; ++i) begin
                    x_prods[i] <= DEQUANT( X_COEFS[i] * x_sh[i] );
                    if (i == 0) y_prods[i] <= 'sh0;
                    else        y_prods[i] <= DEQUANT( Y_COEFS[i] * y_sh[i-1] );
                end
            end

            if (state == S_ADD) begin
                if (full_dec) begin
                    for (int i = TAPS-1; i > 0; i--) y_sh[i] <= y_sh[i-1];
                    y_sh[0] <= current_sum;
                end
            end
        end
    end

endmodule