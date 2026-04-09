
package globals_pkg;

	localparam DWIDTH = 32;

	localparam PIPE_FIFO_DEPTH = 8;

	function automatic void printtime();
		$write( "\n@%0t\t", $time );
	endfunction

endpackage: globals_pkg

