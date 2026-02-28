
module reorder #(
	IDX_WIDTH  = 5,
	IDX_SIZE   = 2 ** IDX_WIDTH, 
	DATA_WIDTH = 32
)(
	input  logic [ IDX_SIZE-1:0 ] [ DATA_WIDTH-1:0 ] din,
	output logic [ IDX_SIZE-1:0 ] [ DATA_WIDTH-1:0 ] dout
);

	function automatic logic [ IDX_WIDTH-1:0 ]
	bitrev ( input logic [ IDX_WIDTH-1:0 ] i );
		logic [ IDX_WIDTH-1:0 ] i_rev = 'h0;
		foreach ( i_rev[ b ] )
		begin
			i_rev[ b ] = i[ IDX_SIZE-1-b ];
		end
		return i_rev;
	endfunction

	logic [ IDX_WIDTH-1:0 ] i;

	always_comb
	begin
		//i = 'h0;
		dout = 'h0;
		foreach ( din[ i ] )
		begin
			dout[ bitrev( i ) ] = din[ i ];
		end
	end

endmodule: reorder

