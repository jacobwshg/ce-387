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

	/* shiftreg buffers */
	logic signed [ DWIDTH-1:0 ] x_sh [ 0:TAPS-1 ];
	logic signed [ DWIDTH-1:0 ] y_sh [ 0:TAPS-1 ];

	logic signed [ DWIDTH-1:0 ] y1, y2, y_c;

	/* idx in decimation batch */
	logic [ $clog2(DECIM):0 ] dec_idx, dec_idx_c;
	/* Whether we have shifted in a full batch of DECIM inputs */
	logic full_dec;
	logic x_sh_en, y_sh_en;

	always_comb
	begin
		// IIR filters natively have a 1-sample output delay to match the C code
		y_out = (TAPS == 1) ? y_c : y_sh[ TAPS-2 ];
		
		x_in_rd_en  = 1'b0;
		y_out_wr_en = 1'b0;

		y1 = 'sh0;
		y2 = 'sh0;
		for ( int i=0; i<TAPS; ++i )
		begin
			y1 += DEQUANT( X_COEFS[ i ] * x_sh[ i ] );
			if ( i == 0 ) begin
				// y_coeffs[0] is mathematically 0 in this standard IIR form.
				y2 += 'sh0; 
			end else begin
				// Multiply using the previous cycle's y_sh to simulate the C code's shift-first behavior
				y2 += DEQUANT( Y_COEFS[ i ] * y_sh[ i-1 ] );
			end
		end
		y_c = y1 + y2;

		dec_idx_c = dec_idx;
		full_dec  = 1'( dec_idx == DECIM );
		
		y_sh_en = full_dec & ~y_out_full;
		// If full_dec is met, we only shift the next x_in if we successfully output y this cycle
		x_sh_en = ( ~full_dec || y_sh_en ) & ~x_in_empty;

		if ( x_sh_en )
		begin
			x_in_rd_en = 1'b1;
			if ( full_dec ) dec_idx_c = 1'h1;
			else            dec_idx_c = dec_idx + 1'h1;
		end
		else if ( y_sh_en )
		begin
			dec_idx_c = 'h0;
		end

		if ( y_sh_en )
		begin
			y_out_wr_en = 1'b1;
		end
	end

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			dec_idx <= 'h0;
			x_sh <= '{ default: 'sh0 };
			y_sh <= '{ default: 'sh0 };
		end
		else 
		begin
			dec_idx <= dec_idx_c;

			if ( x_sh_en )
			begin
				for (int i = TAPS-1; i > 0; i--) x_sh[i] <= x_sh[i-1];
				x_sh[ 0 ] <= x_in;
			end

			if ( y_sh_en )
			begin
				for (int i = TAPS-1; i > 0; i--) y_sh[i] <= y_sh[i-1];
				y_sh[ 0 ] <= y_c;
			end
		end
	end

endmodule: iir