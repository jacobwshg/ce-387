
import weights_pkg::*;

module neuron #(
	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14,

	parameter int INPUT_SIZE = 10,
	parameter int IDX_WIDTH = $clog2( INPUT_SIZE )+1,

	parameter logic signed [ 0:INPUT_SIZE-1 ] [ DATA_WIDTH-1:0 ]
		WEIGHTS = LAYER1_WEIGHTS[0]

)(
	input logic signed [ DATA_WIDTH-1:0 ] acc_in,
	input logic signed [ DATA_WIDTH-1:0 ] din,
	input logic [ IDX_WIDTH-1:0 ] in_idx,

	output logic signed [ DATA_WIDTH-1:0 ] acc_out
);

	localparam logic signed [ DATA_WIDTH-1:0 ] Q_STEP = 1 << FRAC_WIDTH;

	function automatic logic signed [ DATA_WIDTH-1:0 ]
	DEQUANT( input logic signed [ DATA_WIDTH-1:0 ] x );
		/*
		if ( x[DATA_WIDTH-1] && ( -x < Q_STEP ) )
		begin
			return 'sd0;
		end
		*/	
		logic signed [ DATA_WIDTH-1:0 ] q = $signed( x + ( Q_STEP>>1 ) ) >>> FRAC_WIDTH;
		return ( q==-1 ) ? 0 : q;
	endfunction

	logic signed [ DATA_WIDTH-1:0 ] weight;

	assign weight = WEIGHTS[ in_idx ];
	assign acc_out = acc_in + DEQUANT( din * weight );

endmodule: neuron

