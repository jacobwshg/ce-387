
package globals_pkg;

	localparam DWIDTH = 32;

	localparam FIFO_DEPTH = 16;
	localparam PIPE_FIFO_DEPTH = 16;

	function automatic void printtime();
		$write( "\n@%0t\t", $time );
	endfunction

endpackage: globals_pkg

