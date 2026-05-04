
package globals_pkg;

	localparam DWIDTH = 32;

	localparam int N = 16;

	localparam FIFO_DEPTH = N;
	localparam PIPE_FIFO_DEPTH = N;

	function automatic void printtime();
		$write( "\n@%0t\t", $time );
	endfunction

endpackage: globals_pkg

