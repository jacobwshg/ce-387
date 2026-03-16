`timescale 1ns/1ps

module demodulate (
    input  logic               clk,
    input  logic               rst_n,

    input  logic               in_empty,
    output logic               in_rd_en,
    input  logic signed [31:0] real_in,
    input  logic signed [31:0] imag_in,
    input  logic signed [31:0] gain,

    input  logic               out_full,
    output logic               out_wr_en,
    output logic signed [31:0] demod_out
);

    import globals_pkg::*;
    import quant_pkg::*;

    parameter logic signed [31:0] QUAD1 = 32'h0000_0324;
    parameter logic signed [31:0] QUAD3 = 32'h0000_096C;

    typedef enum logic [3:0] {
        S0, S1, S2, S3, S4, S5, S6A, S6B, S6C, S6D, S7, S8A, S8B, S9
    } state_t;

    state_t state;

    logic signed [31:0] real_prev, imag_prev;
    logic signed [31:0] real_latch, imag_latch;
    logic signed [31:0] r_mult1, r_mult2, i_mult1, i_mult2;
    logic signed [31:0] r, i;
    logic signed [31:0] dividend, divisor;
    logic               x_is_pos, y_is_neg;
    logic signed [31:0] latched_gain;

    logic [31:0] a, b, q;
    logic        sign;
    logic signed [31:0] quad1_mult;
    logic [31:0] p_reg;
    logic [31:0] b_shifted, q_shifted;
    logic signed [31:0] angle_val_reg;
    logic signed [31:0] pre_gain_val;

    function automatic logic [31:0] get_msb_pos(input logic [31:0] val);
        for (int k = 31; k >= 0; k--) begin
            if (val[k]) return k;
        end
        return 0;
    endfunction

    assign in_rd_en = (state == S0) && !in_empty && !out_full;

    always_ff @(posedge clk or negedge rst_n) begin
        logic signed [31:0] abs_y_tmp;
        logic [31:0] p_tmp;
        logic signed [31:0] quotient_tmp;

        if (!rst_n) begin
            state        <= S0;
            out_wr_en    <= 1'b0;
            demod_out    <= '0;

            real_prev    <= '0;
            imag_prev    <= '0;
            real_latch   <= '0;
            imag_latch   <= '0;

            r_mult1      <= '0;
            r_mult2      <= '0;
            i_mult1      <= '0;
            i_mult2      <= '0;

            r            <= '0;
            i            <= '0;
            dividend     <= '0;
            divisor      <= '0;
            x_is_pos     <= 1'b0;
            y_is_neg     <= 1'b0;
            latched_gain <= '0;

            a            <= '0;
            b            <= '0;
            q            <= '0;
            sign         <= 1'b0;
            quad1_mult   <= '0;
            p_reg        <= '0;
            b_shifted    <= '0;
            q_shifted    <= '0;
            angle_val_reg<= '0;
            pre_gain_val <= '0;
        end else begin
            out_wr_en <= 1'b0;

            case (state)
                S0: begin
                    if (in_rd_en) begin
                        latched_gain <= gain;
                        real_latch   <= real_in;
                        imag_latch   <= imag_in;
                        state        <= S1;
                    end
                end

                S1: begin
                    r_mult1 <=   real_prev  * real_latch;
                    r_mult2 <= (-imag_prev) * imag_latch;
                    i_mult1 <=   real_prev  * imag_latch;
                    i_mult2 <= (-imag_prev) * real_latch;

                    real_prev <= real_latch;
                    imag_prev <= imag_latch;

                    state <= S2;
                end

                S2: begin
                    r     <= DEQUANT(r_mult1) - DEQUANT(r_mult2);
                    i     <= DEQUANT(i_mult1) + DEQUANT(i_mult2);
                    state <= S3;
                end

                S3: begin
                    abs_y_tmp = (i < 0) ? -i : i;
                    abs_y_tmp = abs_y_tmp + 1;

                    y_is_neg <= (i < 0);
                    x_is_pos <= (r >= 0);

                    if (r >= 0) begin
                        dividend <= (r - abs_y_tmp) <<< FRAC_WIDTH;
                        divisor  <=  r + abs_y_tmp;
                    end else begin
                        dividend <= (r + abs_y_tmp) <<< FRAC_WIDTH;
                        divisor  <=  abs_y_tmp - r;
                    end
                    state <= S4;
                end

                S4: begin
                    a     <= dividend[31] ? -dividend : dividend;
                    b     <= divisor[31]  ? -divisor  : divisor;
                    q     <= '0;
                    sign  <= dividend[31] ^ divisor[31];
                    state <= S5;
                end

                S5: begin
                    if (b == 1) begin
                        q     <= a;
                        state <= S7;
                    end else if (b == 0) begin
                        q     <= '0;
                        state <= S7;
                    end else begin
                        state <= S6A;
                    end
                end

                S6A: begin
                    if ((b != 0) && (b <= a)) begin
                        p_tmp = get_msb_pos(a) - get_msb_pos(b);
                        p_reg <= p_tmp;
                        state <= S6B;
                    end else begin
                        state <= S7;
                    end
                end

                S6B: begin
                    b_shifted <= b << p_reg;
                    q_shifted <= 32'd1 << p_reg;
                    state <= S6C;
                end

                S6C: begin
                    if (b_shifted > a) begin
                        b_shifted <= b_shifted >> 1;
                        q_shifted <= q_shifted >> 1;
                    end
                    state <= S6D;
                end

                S6D: begin
                    q <= q + q_shifted;
                    a <= a - b_shifted;
                    state <= S6A;
                end

                S7: begin
                    quotient_tmp = sign ? -$signed(q) : $signed(q);
                    quad1_mult <= DEQUANT( QUAD1 * quotient_tmp );

                    state    <= S8A;
                end

                S8A: begin
                    angle_val_reg <= (x_is_pos ? QUAD1 : QUAD3) - quad1_mult;
                    state <= S8B;
                end

                S8B: begin
                    pre_gain_val <= y_is_neg ? -angle_val_reg : angle_val_reg;
                    state <= S9;
                end

                S9: begin
                    demod_out <= DEQUANT(latched_gain * pre_gain_val);
                    out_wr_en <= 1'b1;
                    state     <= S0;
                end

                default: state <= S0;
            endcase
        end
    end

endmodule