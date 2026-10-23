
`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string INFILE_RE = "../sim/in_real.txt";
localparam string INFILE_IM = "../sim/in_imag.txt";

localparam string OUTFILE_RE = "../sim/out_real.txt";
localparam string OUTFILE_IM = "../sim/out_imag.txt";

localparam string CMPFILE_RE = "../sim/cmp_real.txt";
localparam string CMPFILE_IM = "../sim/cmp_imag.txt";

localparam int CLOCK_PERIOD = 10;

localparam int N = 32;
localparam int DWIDTH = 32;

localparam int FIFO_DEPTH = 16;
//localparam int PIPE_FIFO_DEPTH = N;

localparam int RE = 0, IM = 1;

`endif

