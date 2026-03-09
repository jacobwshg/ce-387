
`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string INFILE  = "../sim/x_test.txt";
localparam string CMPFILE = "../sim/y_test.txt";

localparam int DATA_WIDTH = 32;
localparam int FRAC_WIDTH = 14;

localparam int FEATURE_CNT = 784;
localparam int LAYER_CNT = 2;
localparam int LAYER_SIZES [ 0:LAYER_CNT-1 ] = { 10, 10 };

localparam int FIFO_DEPTH = 16;

localparam int CLOCK_PERIOD = 10;

`endif

