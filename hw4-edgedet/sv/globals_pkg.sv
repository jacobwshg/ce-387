
package globals_pkg;

	localparam int FRAME_WIDTH  = 720;
	localparam int FRAME_HEIGHT = 540;

	localparam int BYTE_WIDTH = 8;
	localparam int SAFE_BYTE_WIDTH = BYTE_WIDTH + 4;
	localparam int RGB_WIDTH = 3 * BYTE_WIDTH;

	//localparam int ROW_IDX_WIDTH = $clog2( FRAME_HEIGHT );
	//localparam int COL_IDX_WIDTH = $clog2( FRAME_WIDTH  );

	localparam int BOX_DIM = 3;

	localparam int FIFO_DEPTH = 32;

endpackage: globals_pkg

