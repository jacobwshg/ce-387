import uvm_pkg::*;

interface my_uvm_if;
	logic clock;
	logic reset;

	logic in_full;
	logic in_wr_en;
	logic [ 7:0 ] in_din;
	logic in_sof_in;
	logic in_eof_in;

	logic out_empty;
	logic out_rd_en;
	logic [ 7:0 ] out_dout;
	logic out_sof_out;
	logic out_eof_out;

	logic pkt_done;
	logic sum_true;

endinterface: my_uvm_if

