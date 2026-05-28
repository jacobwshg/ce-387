
package quant_pkg;

	import globals_pkg::DWIDTH;
	import globals_pkg::FRACWIDTH;

	//localparam int DWIDTH = globals_pkg::DWIDTH;
	localparam int Q_STEP = 1 << FRACWIDTH;

	function automatic logic signed [ DWIDTH-1:0 ]
	QUANT( input logic signed [ DWIDTH-1:0 ] x );

		return $signed( x << FRACWIDTH );

	endfunction

	function automatic logic signed [ DWIDTH-1:0 ]
	DEQUANT( input logic signed [ DWIDTH-1:0 ] x );

		logic signed [ DWIDTH-1:0 ] dq = $signed( x ) >>> FRACWIDTH;
		// add 1 if x both is negative and 
		// has 1 in the fractional bits
		if ( x[ DWIDTH-1 ] && ( | x[ FRACWIDTH-1:0 ] ) )
		begin
			dq = dq + 1'h1;
		end

		return dq;

	endfunction

endpackage: quant_pkg

