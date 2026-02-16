`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string INFILE = "test.pcap";
localparam string OUTFILE = "output.txt";
localparam string CMPFILE = "test.txt";
//localparam int IMG_WIDTH = 720;
//localparam int IMG_HEIGHT = 540;
//localparam int BMP_HEADER_SIZE = 54;
//localparam int BYTES_PER_PIXEL = 3;
//localparam int BMP_DATA_SIZE = (IMG_WIDTH * IMG_HEIGHT * BYTES_PER_PIXEL);
localparam int CLOCK_PERIOD = 10;

localparam int SOF_BIT = 8;
localparam int EOF_BIT = 9;

`endif

