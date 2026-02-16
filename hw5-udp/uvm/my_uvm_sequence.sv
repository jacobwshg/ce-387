import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
	logic [9:0] bits;

	function new(string name = "");
		super.new(name);
	endfunction: new

	`uvm_object_utils_begin(my_uvm_transaction)
		`uvm_field_int( bits, UVM_ALL_ON )
	`uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
	`uvm_object_utils(my_uvm_sequence)

	function new(string name = "");
		super.new(name);
	endfunction: new

	task body();
		my_uvm_transaction tx;
		int in_file, n_bytes = 0, i = 0;
		logic reached_eof = 1'b0;
		logic [7:0] ch;

		`uvm_info("SEQ_RUN", $sformatf("Loading file %s...", INFILE), UVM_LOW);

		in_file = $fopen(INFILE, "rb");
		if ( !in_file ) begin
			`uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", INFILE));
		end

		//while ( !$feof(in_file) )
		forever
		begin
			tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
			start_item(tx);

			tx.bits = 10'b0;
			reached_eof = $feof( in_file );

			if ( !reached_eof )
			begin
				n_bytes = $fread( ch, in_file, i, 1 );
				tx.bits[7:0] = ch;
			end
			else
			begin
				tx.bits = 10'b0;
				tx.bits[EOF_BIT] = 1'b1;
			end

			//`uvm_info("SEQ_RUN", tx.sprint(), UVM_LOW);
			finish_item(tx);
			++i;

			if ( reached_eof )
			begin
				break;
			end
		end

		`uvm_info("SEQ_RUN", $sformatf("Closing file %s...", INFILE), UVM_LOW);
		$fclose(in_file);
	endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;

