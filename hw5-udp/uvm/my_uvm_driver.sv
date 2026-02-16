import uvm_pkg::*;

class my_uvm_driver extends uvm_driver#(my_uvm_transaction);

	`uvm_component_utils(my_uvm_driver)

	virtual my_uvm_if vif;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
			(.scope("ifs"), .name("vif"), .val(vif)));
	endfunction: build_phase

	virtual task run_phase(uvm_phase phase);
		drive();
	endtask: run_phase

	virtual task drive();
		my_uvm_transaction tx;

		// wait for reset
		@(posedge vif.reset);
		@(negedge vif.reset);

		forever
		begin
			vif.in_din = 8'b0;
			vif.in_wr_en = 1'b0;
			{ vif.in_din, vif.in_sof_in, vif.in_eof_in } = { 8'b0, 1'b0, 1'b0 };

			@( negedge vif.clock ) 
			begin
				if ( ~vif.in_full )
				begin
					seq_item_port.get_next_item(tx);
					{ vif.in_din, vif.in_sof_in, vif.in_eof_in } = { tx.ch, tx.sof, tx.eof };
					$display( "@%0t  in fifo not full, pushing tx item ( %c, %0b, %0b )", $time, tx.ch, tx.sof, tx.eof);

					vif.in_wr_en = 1'b1;
					seq_item_port.item_done();
				end
			end
		end
	endtask: drive

endclass

