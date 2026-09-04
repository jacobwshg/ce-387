
module togray_comb
#(
	parameter int DWIDTH = 32
)(
	input  logic [ DWIDTH-1:0 ] b,
	output logic [ DWIDTH-1:0 ] g
);

	logic [ DWIDTH-1:0 ] g_tmp;

	assign g_tmp = b ^ ( b>>>1 );
	assign g = g_tmp;

endmodule: togray_comb

