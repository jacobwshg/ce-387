
package globals_pkg;

	localparam int FRACWIDTH = 14;

	localparam logic signed [ 31:0 ] PI = 32'sd51472;
	localparam logic signed [ 31:0 ] K  = 32'sd26981;

	localparam logic signed [ 31:0 ] TWO_PI  = PI << 1;
	localparam logic signed [ 31:0 ] HALF_PI = PI >>> 1;
	localparam logic signed [ 31:0 ] INV_K   =
		( ( 32'sd01<<FRACWIDTH ) << FRACWIDTH ) / K;

endpackage: globals_pkg

