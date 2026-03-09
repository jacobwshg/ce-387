
`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string INFILE  = "../sim/x_test.txt";
localparam string CMPFILE = "../sim/y_test.txt";
localparam int INPUT_SIZE = 784;

localparam int DATA_WIDTH = 32;
localparam int FRAC_WIDTH = 14;
localparam int LABEL_WIDTH = 16;

localparam int CLOCK_PERIOD = 10;

`endif

