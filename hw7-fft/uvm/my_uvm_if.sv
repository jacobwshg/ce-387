
import uvm_pkg::*;

interface my_uvm_if;
	logic clock;
	logic reset;

	logic in_full;
	logic in_wr_en;
	logic [ 0:1 ] [ DATA_WIDTH-1:0 ] in_din;
	logic in_valid;

	logic out_empty;
	logic out_rd_en;
	logic [ 0:1 ] [ DATA_WIDTH-1:0 ] out_dout;
	logic out_valid;
endinterface

