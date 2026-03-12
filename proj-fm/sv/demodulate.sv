import globals_pkg::*;
import quant_pkg::*;

module demodulate #(
	parameter int DWIDTH = 32,
	parameter int GAIN = 10
)(
	input logic clk,
	input logic rst,

	input logic signed [ DWIDTH-1:0 ] x_real_in,
	input logic signed [ DWIDTH-1:0 ] x_imag_in,
	input logic x_in_empty,
	input logic y_out_full,

	output logic signed [ DWIDTH-1:0 ] y_out,
	output logic x_in_rd_en,
	output logic y_out_wr_en
);

	logic signed [ DWIDTH-1:0 ] real_prev, real_prev_c;
	logic signed [ DWIDTH-1:0 ] imag_prev, imag_prev_c;

	logic signed [ DWIDTH-1:0 ] r, i;
	logic signed [ DWIDTH-1:0 ] abs_y;
	logic signed [ DWIDTH-1:0 ] num, den, div_r, angle;
	
	logic active;

	localparam logic signed [ DWIDTH-1:0 ] QUAD1 = 32'd804;
	localparam logic signed [ DWIDTH-1:0 ] QUAD3 = 32'd2412;

	always_comb
	begin
		x_in_rd_en = 1'b0;
		y_out_wr_en = 1'b0;
		y_out = 'sh0;

		real_prev_c = real_prev;
		imag_prev_c = imag_prev;

		active = ~x_in_empty & ~y_out_full;

		r = DEQUANT( ( real_prev * x_real_in ) + ( imag_prev * x_imag_in ) );
		i = DEQUANT( ( real_prev * x_imag_in ) - ( imag_prev * x_real_in ) );

		abs_y = ( i < 0 ) ? -i + 1'h1 : i + 1'h1;

		if ( r >= 0 )
		begin
			num = QUANT( r - abs_y );
			den = r + abs_y;
			div_r = num / den;
			angle = QUAD1 - DEQUANT( QUAD1 * div_r );
		end
		else
		begin
			num = QUANT( r + abs_y );
			den = abs_y - r;
			div_r = num / den;
			angle = QUAD3 - DEQUANT( QUAD1 * div_r );
		end

		angle = ( i < 0 ) ? -angle : angle;

		if ( active )
		begin
			x_in_rd_en = 1'b1;
			y_out_wr_en = 1'b1;
			y_out = DEQUANT( GAIN * angle );
			real_prev_c = x_real_in;
			imag_prev_c = x_imag_in;
		end
	end

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			real_prev <= 'sh0;
			imag_prev <= 'sh0;
		end
		else
		begin
			real_prev <= real_prev_c;
			imag_prev <= imag_prev_c;
		end
	end

endmodule: demodulate