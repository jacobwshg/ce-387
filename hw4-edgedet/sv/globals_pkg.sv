
package globals_pkg;

	localparam int IMG_WIDTH  = 720;
	localparam int IMG_HEIGHT = 576;

	localparam int PX_WIDTH = 8;
	localparam int SAFE_PX_WIDTH = PX_WIDTH + 4;
	localparam int RGB_WIDTH = 3 * PX_WIDTH;

	localparam int ROW_IDX_WIDTH = $clog2( IMG_HEIGHT );
	localparam int COL_IDX_WIDTH = $clog2( IMG_WIDTH  );

	localparam int BOX_DIM = 3;

	localparam int FIFO_DEPTH = 32;

endpackage: globals_pkg

