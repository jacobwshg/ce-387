`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
//localparam string INFILE = "test.pcap";
//localparam string OUTFILE = "output.txt";
//localparam string CMPFILE = "test.txt";
//localparam int IMG_WIDTH = 720;
//localparam int IMG_HEIGHT = 540;
//localparam int BMP_HEADER_SIZE = 54;
//localparam int BYTES_PER_PIXEL = 3;
//localparam int BMP_DATA_SIZE = (IMG_WIDTH * IMG_HEIGHT * BYTES_PER_PIXEL);
localparam int CLOCK_PERIOD = 10;

localparam int I_SIN = 0;
localparam int I_COS = 1;

localparam real PI_R = 3.14159265359;

localparam FRAC_WIDTH = 14;
localparam STAGE_CNT = 16;

function automatic real
torad( input int deg );
begin
	return PI_R * ( $itor( deg ) / 180.0 );
end
endfunction

function automatic logic signed [ 31:0 ]
quantize( input real r );
begin
	return 32'( $rtoi( r * $itor( 1 << FRAC_WIDTH ) ) );
end
endfunction

function automatic real
dequantize( input logic signed [ 15:0 ] i16 );
begin
	/*
	logic sgn = i16[15];
	logic signed [ 31:0 ] i32 = 32'sh0;
	for ( int bi=16; bi<32; ++bi )
		i32[bi] = sgn;
	i32[ 15:0 ] = i16;
	*/
	return $itor( int'( i16 ) ) / $itor( 1 << FRAC_WIDTH );
end
endfunction

`endif

