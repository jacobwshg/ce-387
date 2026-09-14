
package globals_pkg;

	localparam int FRAME_WIDTH  = 720;
	localparam int FRAME_HEIGHT = 540;

	localparam int COL_ID_WIDTH = $clog2( FRAME_WIDTH );
	localparam int ROW_ID_WIDTH = $clog2( FRAME_HEIGHT );
	
	localparam int BYTE_WIDTH = 8;
	localparam int SAFE_BYTE_WIDTH = BYTE_WIDTH + 4;
	localparam int RGB_WIDTH = 3 * BYTE_WIDTH;

	localparam int RGB_SUM_WIDTH = $clog2( 3 * 255 );

	//localparam int ROW_IDX_WIDTH = $clog2( FRAME_HEIGHT );
	//localparam int COL_IDX_WIDTH = $clog2( FRAME_WIDTH  );

	localparam int SOBEL_BOX_DIM = 3;

	localparam int FIFO_DEPTH = 32;

	typedef logic [ 0:SOBEL_BOX_DIM-1 ] [ 0:SOBEL_BOX_DIM-1 ] [ BYTE_WIDTH-1:0 ]
		sobel_box_t;

	typedef enum int
	{
		TOP = 0, MIDDLE = 1, BOTTOM = 2
	} rowtag_3_t;

	typedef enum int
	{
		LEFT = 0, CENTER = 1, RIGHT = 2
	} coltag_3_t;

	/*
	 * Store box in col-major order ( right col shifted in )
	 */
	/*
	 * Horizontal gradient kernel
	 * -1  0  1
	 * -2  0  2
	 * -1  0  1
	 */
	function automatic logic signed [ SAFE_BYTE_WIDTH-1:0 ]
	compute_sobel_hgrad( input sobel_box_t box );
		logic signed [ SAFE_BYTE_WIDTH-1:0 ] hgrad = 'h0;
		hgrad = 
			-   box[ 0 ][ 0 ]       +   box[ 2 ][ 0 ]
			- ( box[ 0 ][ 1 ]<<<1 ) + ( box[ 2 ][ 1 ]<<<1 )
			-   box[ 0 ][ 2 ]       +   box[ 2 ][ 2 ];
		return hgrad;
	endfunction

	/*
 	 * Vertical gradient kernel
	 * -1 -2 -1
	 *  0  0  0
	 *  1  2  1
	 */
	function automatic logic signed [ SAFE_BYTE_WIDTH-1:0 ]
	compute_sobel_vgrad( input sobel_box_t box );
		logic signed [ SAFE_BYTE_WIDTH-1:0 ] vgrad = 'h0;
		vgrad = 
			- box[ 0 ][ 0 ] - ( box[ 1 ][ 0 ]<<<1 ) - ( box[ 2 ][ 0 ] )
			+ box[ 0 ][ 2 ] + ( box[ 1 ][ 2 ]<<<1 ) + ( box[ 2 ][ 2 ] );
		return vgrad;
	endfunction

endpackage: globals_pkg

