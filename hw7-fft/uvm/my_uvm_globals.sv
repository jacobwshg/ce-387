
`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam string INFILE_RE = "../sim/infile_re.txt";
localparam string INFILE_IM = "../sim/infile_im.txt";

localparam string OUTFILE_RE = "../sim/output_real.txt";
localparam string OUTFILE_IM = "../sim/output_imag.txt";

localparam string CMPFILE_RE = "../sim/outfile_re.txt";
localparam string CMPFILE_IM = "../sim/outfile_im.txt";

localparam int CLOCK_PERIOD = 10;

localparam int N = 32;
localparam int DWIDTH = 32;

localparam int FIFO_DEPTH = 512;
localparam int PIPE_FIFO_DEPTH = 512;

localparam int RE = 0, IM = 1;

`endif

