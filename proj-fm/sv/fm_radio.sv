`timescale 1ns/1ps
import globals_pkg::*;
import quant_pkg::*;
import constants_pkg::*;

module fm_radio_stereo (
	input  logic		 clk,
	input  logic		 rst_n,
	
	input  logic		 iq_valid_in,
	output logic		 iq_ready_out,
	input  logic [31:0]  iq_data_in,
	
	output logic signed [31:0] left_audio_out,
	output logic			   left_audio_valid,
	input  logic			   left_audio_ready,
	
	output logic signed [31:0] right_audio_out,
	output logic			   right_audio_valid,
	input  logic			   right_audio_ready
);

	logic signed [31:0] i_quant, q_quant;
	logic iq_quant_valid;
	
	read_iq u_read_iq (
		.in_valid(iq_valid_in), .in(iq_data_in),
		.I(i_quant), .Q(q_quant), .out_valid(iq_quant_valid)
	);

	logic [31:0] f_iq_i_dout, f_iq_q_dout;
	logic f_iq_i_full, f_iq_q_full, f_iq_i_empty, f_iq_q_empty;
	logic fir_i_rd, fir_q_rd;

	fifo #(.FIFO_BUFFER_SIZE(128)) f_iq_i (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(iq_quant_valid), .din(i_quant), .full(f_iq_i_full),
		.rd_clk(clk), .rd_en(fir_i_rd), .dout(f_iq_i_dout), .empty(f_iq_i_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_iq_q (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(iq_quant_valid), .din(q_quant), .full(f_iq_q_full),
		.rd_clk(clk), .rd_en(fir_q_rd), .dout(f_iq_q_dout), .empty(f_iq_q_empty)
	);
	assign iq_ready_out = !( f_iq_i_full | f_iq_q_full );

	logic signed [31:0] i_fir_val, q_fir_val;
	logic i_fir_wr, q_fir_wr;
	logic f_ifir_full, f_qfir_full;

	fir #(.TAPS(CHANNEL_COEFF_TAPS), .DECIM(1), .X_COEFS(CHANNEL_COEFFS_REAL)) u_fir_i (
		.clk(clk), .rst(!rst_n),
		.x_in(f_iq_i_dout), .x_in_empty(f_iq_i_empty), .x_in_rd_en(fir_i_rd),
		.y_out(i_fir_val), .y_out_full(f_ifir_full), .y_out_wr_en(i_fir_wr)
	);
	fir #(.TAPS(CHANNEL_COEFF_TAPS), .DECIM(1), .X_COEFS(CHANNEL_COEFFS_REAL)) u_fir_q (
		.clk(clk), .rst(!rst_n),
		.x_in(f_iq_q_dout), .x_in_empty(f_iq_q_empty), .x_in_rd_en(fir_q_rd),
		.y_out(q_fir_val), .y_out_full(f_qfir_full), .y_out_wr_en(q_fir_wr)
	);

	logic [31:0] f_ifir_dout, f_qfir_dout;
	logic f_ifir_empty, f_qfir_empty, demod_rd;

	fifo #(.FIFO_BUFFER_SIZE(128)) f_ifir (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(i_fir_wr), .din(i_fir_val), .full(f_ifir_full),
		.rd_clk(clk), .rd_en(demod_rd), .dout(f_ifir_dout), .empty(f_ifir_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_qfir (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(q_fir_wr), .din(q_fir_val), .full(f_qfir_full),
		.rd_clk(clk), .rd_en(demod_rd), .dout(f_qfir_dout), .empty(f_qfir_empty)
	);

	logic signed [31:0] demod_val;
	logic demod_wr;
	logic f_d_lpr_full, f_d_pilot_full, f_d_lmrbp_full;

	demodulate u_demod (
		.clk(clk), .rst_n(rst_n),

		.in_empty(f_ifir_empty | f_qfir_empty), .in_rd_en(demod_rd),
		.real_in(f_ifir_dout), .imag_in(f_qfir_dout),

		.gain(32'sd758),

		.out_full(f_d_lpr_full | f_d_pilot_full | f_d_lmrbp_full), .out_wr_en(demod_wr),
		.demod_out(demod_val)
	);

	logic [31:0] f_d_lpr_dout, f_d_pilot_dout, f_d_lmrbp_dout;
	logic f_d_lpr_empty, f_d_pilot_empty, f_d_lmrbp_empty;
	logic lpr_rd, pilot_rd, lmrbp_rd;

	fifo #(.FIFO_BUFFER_SIZE(128)) f_d_lpr (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(demod_wr), .din(demod_val), .full(f_d_lpr_full),
		.rd_clk(clk), .rd_en(lpr_rd), .dout(f_d_lpr_dout), .empty(f_d_lpr_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_d_pilot (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(demod_wr), .din(demod_val), .full(f_d_pilot_full),
		.rd_clk(clk), .rd_en(pilot_rd), .dout(f_d_pilot_dout), .empty(f_d_pilot_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_d_lmrbp (
		.reset(!rst_n), .wr_clk(clk), .wr_en(demod_wr), .din(demod_val), .full(f_d_lmrbp_full),
		.rd_clk(clk), .rd_en(lmrbp_rd), .dout(f_d_lmrbp_dout), .empty(f_d_lmrbp_empty)
	);

	logic signed [31:0] lpr_val;
	logic lpr_wr, f_lpr_add_full, f_lpr_sub_full;

	fir #(.TAPS(AUDIO_LPR_COEFF_TAPS), .DECIM(AUDIO_DECIM), .X_COEFS(AUDIO_LPR_COEFFS)) u_fir_lpr (
		.clk(clk), .rst(!rst_n),
		.x_in(f_d_lpr_dout), .x_in_empty(f_d_lpr_empty), .x_in_rd_en(lpr_rd),
		.y_out(lpr_val), .y_out_full(f_lpr_add_full | f_lpr_sub_full), .y_out_wr_en(lpr_wr)
	);

	logic [31:0] f_lpr_add_dout, f_lpr_sub_dout;
	logic f_lpr_add_empty, f_lpr_sub_empty, add_lpr_rd, sub_lpr_rd;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_lpr_add (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(lpr_wr), .din(lpr_val), .full(f_lpr_add_full),
		.rd_clk(clk), .rd_en(add_lpr_rd), .dout(f_lpr_add_dout), .empty(f_lpr_add_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_lpr_sub (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(lpr_wr), .din(lpr_val), .full(f_lpr_sub_full),
		.rd_clk(clk), .rd_en(sub_lpr_rd), .dout(f_lpr_sub_dout), .empty(f_lpr_sub_empty)
	);

	logic signed [31:0] pilot_val, sq_val, hp_val, lmrbp_val, mix_val, lmr_val;
	logic pilot_wr, sq_wr, hp_wr, lmrbp_wr, mix_wr, lmr_wr;
	logic f_p1_full, f_p2_full, f_sq_full, f_hp_full, f_lmrbp_full, f_mix_full;
	logic f_lmr_add_full, f_lmr_sub_full;

	fir #(.TAPS(BP_PILOT_COEFF_TAPS), .DECIM(1), .X_COEFS(BP_PILOT_COEFFS)) u_fir_pilot (
		.clk(clk), .rst(!rst_n),
		.x_in(f_d_pilot_dout), .x_in_empty(f_d_pilot_empty), .x_in_rd_en(pilot_rd),
		.y_out(pilot_val), .y_out_full(f_p1_full | f_p2_full), .y_out_wr_en(pilot_wr)
	);
	
	logic [31:0] f_p1_dout, f_p2_dout; logic f_p1_empty, f_p2_empty, sq_rd1, sq_rd2;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_p1 (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(pilot_wr), .din(pilot_val), .full(f_p1_full),
		.rd_clk(clk), .rd_en(sq_rd1), .dout(f_p1_dout), .empty(f_p1_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_p2 (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(pilot_wr), .din(pilot_val), .full(f_p2_full),
		.rd_clk(clk), .rd_en(sq_rd2), .dout(f_p2_dout), .empty(f_p2_empty)
	);

	multiply u_sq (
		.clk(clk), .rst(!rst_n),
		.x_in(f_p1_dout), .x_in_empty(f_p1_empty), .x_in_rd_en(sq_rd1),
		.y_in(f_p2_dout), .y_in_empty(f_p2_empty), .y_in_rd_en(sq_rd2),
		.y_out(sq_val), .y_out_full(f_sq_full), .y_out_wr_en(sq_wr)
	);
	logic [31:0] f_sq_dout; logic f_sq_empty, hp_rd;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_sq (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(sq_wr), .din(sq_val), .full(f_sq_full), 
		.rd_clk(clk), .rd_en(hp_rd), .dout(f_sq_dout), .empty(f_sq_empty)
	);

	fir #(.TAPS(HP_COEFF_TAPS), .DECIM(1), .X_COEFS(HP_COEFFS)) u_fir_hp (
		.clk(clk), .rst(!rst_n),
		.x_in(f_sq_dout), .x_in_empty(f_sq_empty), .x_in_rd_en(hp_rd),
		.y_out(hp_val), .y_out_full(f_hp_full), .y_out_wr_en(hp_wr)
	);
	logic [31:0] f_hp_dout; logic f_hp_empty, mix_rd_hp;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_hp (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(hp_wr), .din(hp_val), .full(f_hp_full),
		.rd_clk(clk), .rd_en(mix_rd_hp), .dout(f_hp_dout), .empty(f_hp_empty)
	);

	fir #(.TAPS(BP_LMR_COEFF_TAPS), .DECIM(1), .X_COEFS(BP_LMR_COEFFS)) u_fir_lmr_bp (
		.clk(clk), .rst(!rst_n),
		.x_in(f_d_lmrbp_dout), .x_in_empty(f_d_lmrbp_empty), .x_in_rd_en(lmrbp_rd),
		.y_out(lmrbp_val), .y_out_full(f_lmrbp_full), .y_out_wr_en(lmrbp_wr)
	);
	logic [31:0] f_lmrbp_dout;
	logic f_lmrbp_empty, mix_rd_bp;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_lmrbp (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(lmrbp_wr), .din(lmrbp_val), .full(f_lmrbp_full),
		.rd_clk(clk), .rd_en(mix_rd_bp), .dout(f_lmrbp_dout), .empty(f_lmrbp_empty)
	);

	multiply u_mix
	(
		.clk(clk), .rst(!rst_n),
		.x_in(f_hp_dout), .x_in_empty(f_hp_empty), .x_in_rd_en(mix_rd_hp),
		.y_in(f_lmrbp_dout), .y_in_empty(f_lmrbp_empty), .y_in_rd_en(mix_rd_bp),
		.y_out(mix_val), .y_out_full(f_mix_full), .y_out_wr_en(mix_wr)
	);
	logic [31:0] f_mix_dout; logic f_mix_empty, lmr_rd;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_mix (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(mix_wr), .din(mix_val), .full(f_mix_full),
		.rd_clk(clk), .rd_en(lmr_rd), .dout(f_mix_dout), .empty(f_mix_empty)
	);

	fir #(.TAPS(AUDIO_LMR_COEFF_TAPS), .DECIM(AUDIO_DECIM), .X_COEFS(AUDIO_LMR_COEFFS)) u_fir_lmr (
		.clk(clk), .rst(!rst_n),
		.x_in(f_mix_dout), .x_in_empty(f_mix_empty), .x_in_rd_en(lmr_rd),
		.y_out(lmr_val), .y_out_full(f_lmr_add_full | f_lmr_sub_full), .y_out_wr_en(lmr_wr)
	);

	logic [31:0] f_lmr_add_dout, f_lmr_sub_dout;
	logic f_lmr_add_empty, f_lmr_sub_empty, add_lmr_rd, sub_lmr_rd;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_lmr_add (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(lmr_wr), .din(lmr_val), .full(f_lmr_add_full),	
		.rd_clk(clk), .rd_en(add_lmr_rd), .dout(f_lmr_add_dout), .empty(f_lmr_add_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_lmr_sub (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(lmr_wr), .din(lmr_val), .full(f_lmr_sub_full),
		.rd_clk(clk), .rd_en(sub_lmr_rd), .dout(f_lmr_sub_dout), .empty(f_lmr_sub_empty)
	);

	logic signed [31:0] add_val, sub_val;
	logic add_wr, sub_wr, f_add_full, f_sub_full;

	add u_add (
		.clk(clk), .rst(!rst_n),
		.x_in(f_lpr_add_dout), .x_in_empty(f_lpr_add_empty), .x_in_rd_en(add_lpr_rd),
		.y_in(f_lmr_add_dout), .y_in_empty(f_lmr_add_empty), .y_in_rd_en(add_lmr_rd),
		.y_out(add_val), .y_out_full(f_add_full), .y_out_wr_en(add_wr)
	);
	sub u_sub (
		.clk(clk), .rst(!rst_n),
		.x_in(f_lpr_sub_dout), .x_in_empty(f_lpr_sub_empty), .x_in_rd_en(sub_lpr_rd),
		.y_in(f_lmr_sub_dout), .y_in_empty(f_lmr_sub_empty), .y_in_rd_en(sub_lmr_rd),
		.y_out(sub_val), .y_out_full(f_sub_full), .y_out_wr_en(sub_wr)
	);

	logic [31:0] f_add_dout, f_sub_dout;
	logic f_add_empty, f_sub_empty, iir_l_rd, iir_r_rd;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_add (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(add_wr), .din(add_val), .full(f_add_full),
		.rd_clk(clk), .rd_en(iir_l_rd), .dout(f_add_dout), .empty(f_add_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_sub (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(sub_wr), .din(sub_val), .full(f_sub_full),
		.rd_clk(clk), .rd_en(iir_r_rd), .dout(f_sub_dout), .empty(f_sub_empty)
	);

	logic signed [31:0] iir_l_val, iir_r_val;
	logic iir_l_wr, iir_r_wr, f_iir_l_full, f_iir_r_full;

	iir #(.TAPS(IIR_COEFF_TAPS), .DECIM(1), .X_COEFS(IIR_X_COEFFS), .Y_COEFS(IIR_Y_COEFFS)) u_iir_l (
		.clk(clk), .rst(!rst_n),
		.x_in(f_add_dout), .x_in_empty(f_add_empty), .x_in_rd_en(iir_l_rd),
		.y_out(iir_l_val), .y_out_full(f_iir_l_full), .y_out_wr_en(iir_l_wr)
	);
	iir #(.TAPS(IIR_COEFF_TAPS), .DECIM(1), .X_COEFS(IIR_X_COEFFS), .Y_COEFS(IIR_Y_COEFFS)) u_iir_r (
		.clk(clk), .rst(!rst_n),
		.x_in(f_sub_dout), .x_in_empty(f_sub_empty), .x_in_rd_en(iir_r_rd),
		.y_out(iir_r_val), .y_out_full(f_iir_r_full), .y_out_wr_en(iir_r_wr)
	);

	logic [31:0] f_iir_l_dout, f_iir_r_dout;
	logic f_iir_l_empty, f_iir_r_empty, gain_l_rd, gain_r_rd;
	fifo #(.FIFO_BUFFER_SIZE(128)) f_iir_l (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(iir_l_wr), .din(iir_l_val), .full(f_iir_l_full),
		.rd_clk(clk), .rd_en(gain_l_rd), .dout(f_iir_l_dout), .empty(f_iir_l_empty)
	);
	fifo #(.FIFO_BUFFER_SIZE(128)) f_iir_r (
		.reset(!rst_n),
		.wr_clk(clk), .wr_en(iir_r_wr), .din(iir_r_val), .full(f_iir_r_full),
		.rd_clk(clk), .rd_en(gain_r_rd), .dout(f_iir_r_dout), .empty(f_iir_r_empty)
	);

	gain #(.GAIN_VAL(VOLUME_LEVEL)) u_gain_l (
		.clk(clk), .rst(!rst_n),
		.x_in(f_iir_l_dout), .x_in_empty(f_iir_l_empty), .x_in_rd_en(gain_l_rd),
		.y_out(left_audio_out), .y_out_full(!left_audio_ready), .y_out_wr_en(left_audio_valid)
	);
	gain #(.GAIN_VAL(VOLUME_LEVEL)) u_gain_r (
		.clk(clk), .rst(!rst_n),
		.x_in(f_iir_r_dout), .x_in_empty(f_iir_r_empty), .x_in_rd_en(gain_r_rd),
		.y_out(right_audio_out), .y_out_full(!right_audio_ready), .y_out_wr_en(right_audio_valid)
	);

endmodule

