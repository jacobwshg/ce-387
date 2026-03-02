
`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string INFILE_RE = "fft_in_real.txt";
localparam string INFILE_IM = "fft_in_imag.txt";

localparam string OUTFILE_RE = "output_real.txt";
localparam string OUTFILE_IM = "output_imag.txt";

localparam string CMPFILE_RE = "fft_out_real.txt";
localparam string CMPFILE_IM = "fft_out_imag.txt";

localparam int CLOCK_PERIOD = 10;

localparam int N = 32;
localparam int DATA_WIDTH = 32;

localparam int RE = 0, IM = 1;

`endif

