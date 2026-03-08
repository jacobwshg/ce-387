
module neuron #(
	parameter int INPUT_SIZE = 10,
	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14,
	parameter int IDX_WIDTH = 16,
	parameter logic signed [ 0:INPUT_SIZE-1 ] [ DATA_WIDTH-1:0 ] WEIGHTS
)(
	input logic signed [ DATA_WIDTH-1:0 ] acc_in,
	input logic signed [ DATA_WIDTH-1:0 ] din,
	input logic [ IDX_WIDTH-1:0 ] in_idx,

	output logic signed [ DATA_WIDTH-1:0 ] acc_out
);

	localparam logic signed [ DATA_WIDTH-1:0 ] Q_STEP = 1 << FRAC_WIDTH;

	function automatic logic signed [ DATA_WIDTH-1:0 ]
	DEQUANT( input logic signed [ DATA_WIDTH-1:0 ] x );
		if ( x[DATA_WIDTH-1] && ( -x < Q_STEP ) )
		begin
			return 'sd0;
		end
		return ( x + ( Q_STEP>>1 ) ) >>> FRAC_WIDTH;
	endfunction

	always_comb
	begin
		acc_out = acc_in + DEQUANT( din * WEIGHTS[ in_idx ] );
	end

endmodule: neuron

