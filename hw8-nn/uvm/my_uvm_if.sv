
import uvm_pkg::*;

interface my_uvm_if;

	logic clock;
	logic reset;

	logic signed [ DATA_WIDTH-1:0 ] din;
	logic in_wr_en;

	logic in_full;
	logic done;
	logic [ DATA_WIDTH-1:0 ] dout;

endinterface

