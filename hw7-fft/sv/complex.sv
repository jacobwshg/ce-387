
package my_complex;

	localparam logic [ 0:0 ]
		I_RE = 0,
		I_IM = 1;

	typedef logic signed [ 1:0 ] [ 31:0 ] complex_t;

	struct Complex #( DATA_WIDTH = 32 )
	{
		logic signed [ DATA_WIDTH-1:0 ] re;
		logic signed [ DATA_WIDTH-1:0 ] im;
	};

endpackage: my_complex

