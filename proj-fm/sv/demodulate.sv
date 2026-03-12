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
        S0, S1, S2, S3, S4, S5, S6, S7, S8
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
    logic               sign;
    logic signed [31:0] quotient;

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
        logic signed [31:0] quad1_mult_tmp;
        logic signed [31:0] angle_val_tmp;

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
            quotient     <= '0;
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
                    r_mult1 <= real_prev * real_latch;
                    r_mult2 <= (-imag_prev) * imag_latch;
                    i_mult1 <= real_prev * imag_latch;
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
                        divisor  <= r + abs_y_tmp;
                    end else begin
                        dividend <= (r + abs_y_tmp) <<< FRAC_WIDTH;
                        divisor  <= abs_y_tmp - r;
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
                        state <= S6;
                    end
                end

                S6: begin
                    if ((b != 0) && (b <= a)) begin
                        p_tmp = get_msb_pos(a) - get_msb_pos(b);
                        if ((b << p_tmp) > a)
                            p_tmp = p_tmp - 1;

                        q <= q + (32'd1 << p_tmp);
                        a <= a - (b << p_tmp);
                    end else begin
                        state <= S7;
                    end
                end

                S7: begin
                    quotient <= sign ? -$signed(q) : $signed(q);
                    state    <= S8;
                end

                S8: begin
                    quad1_mult_tmp = DEQUANT(QUAD1 * quotient);
                    angle_val_tmp  = (x_is_pos ? QUAD1 : QUAD3) - quad1_mult_tmp;

                    demod_out <= DEQUANT(latched_gain * (y_is_neg ? -angle_val_tmp : angle_val_tmp));
                    out_wr_en <= 1'b1;
                    state     <= S0;
                end

                default: state <= S0;
            endcase
        end
    end

endmodule