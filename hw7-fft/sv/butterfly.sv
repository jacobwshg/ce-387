
module butterfly
#(
	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14
)
(
	input  logic clk,
	input  logic signed [ DATA_WIDTH-1:0 ]
		in1_real, in1_imag,
		in2_real, in2_imag,
		w_real, w_imag,
	output logic signed [ DATA_WIDTH-1:0 ]
		out1_real, out1_imag,
		out2_real, out2_imag
);
	import quant_pkg::DEQUANT;

	logic signed [ DATA_WIDTH-1:0 ]
		in1_real_r, in1_imag_r,
		in2_real_r, in2_imag_r,
		w_real_r,   w_imag_r;

	logic signed [ DATA_WIDTH-1:0 ] v_real, v_imag;

	logic signed [ DATA_WIDTH-1:0 ] p1, p2, p3, p4; 

	logic signed [ DATA_WIDTH-1:0 ]
		out1_real_c, out1_imag_c,
		out2_real_c, out2_imag_c;

	logic signed [ DATA_WIDTH-1:0 ]
		out1_real_r, out1_imag_r,
		out2_real_r, out2_imag_r;


	always_ff @( posedge clk )
	begin
		in1_real_r <= in1_real; in1_imag_r <= in1_imag;
		in2_real_r <= in2_real; in2_imag_r <= in2_imag;
		w_real_r   <= w_real;   w_imag_r   <= w_imag;

		out1_real_r <= out1_real_c; out1_imag_r <= out1_imag_c;
		out2_real_r <= out2_real_c; out2_imag_r <= out2_imag_c;
	end

	always_comb
	begin
		// w * in2
		p1 = quant_pkg::DEQUANT( in2_real_r * w_real_r );
		p2 = quant_pkg::DEQUANT( in2_imag_r * w_imag_r );
		p3 = quant_pkg::DEQUANT( in2_real_r * w_imag_r );
		p4 = quant_pkg::DEQUANT( in2_imag_r * w_real_r );

		v_real = p1 - p2;
		v_imag = p3 + p4;

		out1_real_c = in1_real_r + v_real;
		out1_imag_c = in1_imag_r + v_imag;
		out2_real_c = in1_real_r - v_real;
		out2_imag_c = in1_imag_r - v_imag;

	end

	assign out1_real = out1_real_r;
	assign out1_imag = out1_imag_r;
	assign out2_real = out2_real_r;
	assign out2_imag = out2_imag_r;

endmodule: butterfly

