import uvm_pkg::*;

`uvm_analysis_imp_decl(_output)
`uvm_analysis_imp_decl(_compare)

class my_uvm_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(my_uvm_scoreboard)

	uvm_analysis_export #(my_uvm_transaction) sb_export_output;
	uvm_analysis_export #(my_uvm_transaction) sb_export_compare;

	uvm_tlm_analysis_fifo #(my_uvm_transaction) output_fifo;
	uvm_tlm_analysis_fifo #(my_uvm_transaction) compare_fifo;

	my_uvm_transaction tx_out;
	my_uvm_transaction tx_cmp;

	function new(string name, uvm_component parent);
		super.new(name, parent);
		tx_out = new("tx_out");
		tx_cmp = new("tx_cmp");
	endfunction: new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		sb_export_output = new("sb_export_output", this);
		sb_export_compare = new("sb_export_compare", this);

		output_fifo	= new("output_fifo", this);
		compare_fifo = new("compare_fifo", this);
	endfunction: build_phase

	virtual function void connect_phase(uvm_phase phase);
		sb_export_output.connect(output_fifo.analysis_export);
		sb_export_compare.connect(compare_fifo.analysis_export);
	endfunction: connect_phase

	virtual task run();
		forever begin
			output_fifo.get(tx_out);
			compare_fifo.get(tx_cmp);			
			comparison();
		end
	endtask: run

	virtual function void comparison();
		begin
			// use uvm_error to report errors and continue
			// use uvm_fatal to halt the simulation on error
			`uvm_info(
				"SB_CMP",
				$sformatf(
					"\n\tdeg: %d, rad: %f\n\t\tSW sin: %f, HW sin (dequant): %f, error: %f\n\t\tSW cos: %f, HW cos (dequant): %f, error: %f\n",
					tx_cmp.deg, tx_cmp.rad_r,
					tx_cmp.sin_r, tx_out.sin_r, ( tx_out.sin_r - tx_cmp.sin_r ),
					tx_cmp.cos_r, tx_out.cos_r, ( tx_out.cos_r - tx_cmp.cos_r ) 
				),
				UVM_LOW
			);
		end
	endfunction: comparison

endclass: my_uvm_scoreboard

