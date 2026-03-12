
import globals_pkg::*;
import quant_pkg::*;

module iir #(
	parameter int DWIDTH = 32,
	parameter int TAPS = 32,
	parameter int DECIM = 8,
	parameter logic signed [ DWIDTH-1:0 ] X_COEFS [ 0:TAPS-1 ],
	parameter logic signed [ DWIDTH-1:0 ] Y_COEFS [ 0:TAPS-1 ]
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
		y_out = y_sh[ TAPS-1 ];
		x_in_rd_en = 1'b0;
		y_out_wr_en = 1'b0;

		y1 = 'sh0;
		y2 = 'sh0;
		for ( int i=0; i<TAPS; ++i )
		begin
			y1 += DEQUANT( X_COEFS[ i ] * x_sh[ i ] );
			y2 += DEQUANT( Y_COEFS[ i ] * y_sh[ i ] );
		end
		y_c = y1 + y2;

		dec_idx_c = dec_idx;
		full_dec = 1'( dec_idx==DECIM );
		x_sh_en = ( ~full_dec ) & ~x_in_empty;
		y_sh_en =    full_dec   & ~y_out_full;

		if ( x_sh_en )
		begin
			x_in_rd_en = 1'b1;
			dec_idx_c = dec_idx + 1'h1;
		end

		if ( y_sh_en )
		begin
			y_out_wr_en = 1'b1;
			dec_idx_c = 'h0;
		end

	end

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			dec_idx = 'h0;
			x_sh <= '{ default: 'sh0 };
			y_sh <= '{ default: 'sh0 };
		end
		else 
		begin
			dec_idx <= dec_idx_c;

			if ( x_sh_en )
			begin
				x_sh[ 1:TAPS-1 ] <= x_sh[ 0:TAPS-2 ];
				x_sh[ 0 ]        <= x_in;
			end

			/*
			 * During cycles where registered decimation idx reaches DECIM,
			 * the previous group of cycles shifted in precisely DECIM values
			 * and allows the current cycle's combinatorial math to compute
			 * a valid y output.
			 */
			if ( y_sh_en )
			begin
				y_sh[ 1:TAPS-1 ] <= y_sh[ 0:TAPS-2 ];
				y_sh[ 0 ] <= y_c;
			end

		end
	end

endmodule: iir

