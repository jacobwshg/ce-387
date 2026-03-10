

package quant_pkg;

	import globals_pkg::*;

	function automatic logic signed [ DWIDTH-1:0 ]
	QUANT( input logic signed [ DWIDTH-1:0 ] x );

		return $signed( x << FRAC_WIDTH );

	endfunction

	function automatic logic signed [ DWIDTH-1:0 ]
	DEQUANT( input logic signed [ DWIDTH-1:0 ] x );

		if ( x[ DWIDTH-1 ] && ( -x < Q_STEP ) )
		begin
			return 'sd0;
		end
		return $signed( x + ( Q_STEP>>1 ) ) >>> FRAC_WIDTH;

	endfunction

endpackage: quant_pkg

