
package globals_pkg;

	localparam DWIDTH = 32;

	localparam int N = 32;
	localparam int LOG2_N = $clog2( N );

	localparam FIFO_DEPTH = 16;
	//localparam PIPE_FIFO_DEPTH = N;

	function automatic void printtime();
		$write( "\n@ %0t\t", $time );
	endfunction

endpackage: globals_pkg

