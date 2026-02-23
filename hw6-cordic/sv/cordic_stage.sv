
module cordic_stage
(
	input logic clk,
	input logic rst,
	input logic sh_en,

	input logic signed [ 15:0 ] x_in,
	input logic signed [ 15:0 ] y_in,
	input logic signed [ 15:0 ] z_in,
	input logic signed [ 15:0 ] k,
	input logic signed [ 15:0 ] c,

	output logic signed [ 15:0 ] x_out,
	output logic signed [ 15:0 ] y_out,
	output logic signed [ 15:0 ] z_out
);
	logic signed [ 15:0 ] x_c, y_c, z_c;
	logic sgn;
	logic signed [ 15:0 ] sgn16;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			//{ x_out, y_out, z_out } <= 'h0;
			x_out <= 'h0;
			y_out <= 'h0;
			z_out <= 'h0;
		end
		else if ( sh_en )
		begin
			x_out <= x_c;
			y_out <= y_c;
			z_out <= z_c;
		end
	end

	always_comb
	begin
		sgn = z_in[15];
		sgn16 = { 16 { sgn } };
		x_c = x_in - ( ( ( y_in >>> k ) ^ sgn16 ) + sgn );
		y_c = y_in - ( ( ( x_in >>> k ) ^ sgn16 ) + sgn );
		z_c = z_in - ( (   c            ^ sgn16 ) + sgn );
	end

endmodule: cordic_stage

