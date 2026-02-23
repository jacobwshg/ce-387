import uvm_pkg::*;

interface my_uvm_if;
	logic clock;
	logic reset;

	logic in_full;
	logic in_wr_en;
	logic signed [ 31:0 ] in_in;

	logic out_empty;
	logic out_rd_en;
	logic signed [ 1:0 ] [ 15:0 ] out_out;

endinterface

