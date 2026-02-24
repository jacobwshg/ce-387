
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
	logic signed [ 15:0 ] xtanc, ytanc;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
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
		sgn = z_in[ 15 ];

		xtanc = x_in >>> k;
		ytanc = y_in >>> k;

		x_c = x_in - ( sgn ? -ytanc : ytanc );
		y_c = y_in + ( sgn ? -xtanc : xtanc );
		z_c = z_in - ( sgn ? -c : c );
	end

endmodule: cordic_stage

