
import uvm_pkg::*;

class my_uvm_coverage extends uvm_subscriber #(my_uvm_transaction);
	`uvm_component_utils(my_uvm_coverage)

	my_uvm_transaction tx;

	covergroup cg;
		coverpoint tx.re
		{
			bins re_pos = { [ 32'h0000_0000 : 32'h7fff_ffff ] };
			bins re_neg = { [ 32'h1000_0000 : 32'hffff_ffff ] };
		}
		coverpoint tx.im
		{
			bins im_pos = { [ 32'h0000_0000 : 32'h7fff_ffff ] };
			bins im_neg = { [ 32'h1000_0000 : 32'hffff_ffff ] };
		}
	endgroup

	function new(string name, uvm_component parent);
		super.new(name,parent);
		cg = new(); 
	endfunction

	function void write(my_uvm_transaction t);
		tx = t;
		cg.sample();
	endfunction

	virtual function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info("COV", $sformatf("Coverage: %0.2f%%", cg.get_coverage()), UVM_LOW)
	endfunction
endclass

