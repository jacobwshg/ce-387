
`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string INFILE_RE = "../sim/fft_in_real.txt";
localparam string INFILE_IM = "../sim/fft_in_imag.txt";

localparam string OUTFILE_RE = "../sim/output_real.txt";
localparam string OUTFILE_IM = "../sim/output_imag.txt";

localparam string CMPFILE_RE = "../sim/fft_out_real.txt";
localparam string CMPFILE_IM = "../sim/fft_out_imag.txt";

localparam int CLOCK_PERIOD = 10;

localparam int N = 32;
localparam int DATA_WIDTH = 32;

localparam int RE = 0, IM = 1;

`endif

