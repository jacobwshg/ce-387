import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
	int  deg = 0;
	real rad_r = 0.0;
	logic signed [ 31:0 ] rad = 32'sd0;
	real sin_r = 0.0;
	real cos_r = 0.0;

	function new(string name = "");
		super.new(name);
	endfunction: new

	`uvm_object_utils_begin(my_uvm_transaction)
		`uvm_field_int( deg, UVM_ALL_ON )
		`uvm_field_real( rad_r, UVM_ALL_ON )
		`uvm_field_int( rad, UVM_ALL_ON )
		`uvm_field_real( sin_r, UVM_ALL_ON )
		`uvm_field_real( cos_r, UVM_ALL_ON )
	`uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
	`uvm_object_utils(my_uvm_sequence)

	function new(string name = "");
		super.new(name);
	endfunction: new

	task body();
		my_uvm_transaction tx;

		// send quantized radians to DUT
		// send extra 16 to push final results out of pipeline
		for ( int deg = -360; deg <= 360 + STAGE_CNT; ++deg )
		begin
			real rad_r = deg <= 360 ? torad( deg ) : 0.0;
			logic signed [ 31:0 ] rad = quantize( rad_r );

			tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
			start_item(tx);

			tx.rad = rad;

			//`uvm_info("SEQ_RUN", tx.sprint(), UVM_LOW);
			finish_item(tx);
		end

	endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;

