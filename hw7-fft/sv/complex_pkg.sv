
package complex_pkg;

	localparam logic [ 0:0 ]
		RE = 0,
		IM = 1;

	typedef logic signed [ 1:0 ] [ 31:0 ] complex_t;

	struct Complex #( DATA_WIDTH = 32 )
	{
		logic signed [ DATA_WIDTH-1:0 ] re;
		logic signed [ DATA_WIDTH-1:0 ] im;
	};

endpackage: complex_pkg

