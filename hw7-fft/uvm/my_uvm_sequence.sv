
import uvm_pkg::*;

class my_uvm_transaction extends uvm_sequence_item;
	logic signed [ DATA_WIDTH-1:0 ] re = 'sh0;
	logic signed [ DATA_WIDTH-1:0 ] im = 'sh0;
	logic valid = 1'b0;

	function new(string name = "");
		super.new(name);
	endfunction: new

	`uvm_object_utils_begin(my_uvm_transaction)
		`uvm_field_int(re, UVM_ALL_ON)
		`uvm_field_int(im, UVM_ALL_ON)
		`uvm_field_int(valid, UVM_ALL_ON)
	`uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
	`uvm_object_utils(my_uvm_sequence)

	function new(string name = "");
		super.new(name);
	endfunction: new

	task body();
		my_uvm_transaction tx;
		int infile_re, infile_im;
		int n_bytes=0, i=0;
		logic signed [ DATA_WIDTH-1:0 ] re, im;

		`uvm_info("SEQ_RUN", $sformatf("Loading real infile %s...", INFILE_RE ), UVM_LOW);
		`uvm_info("SEQ_RUN", $sformatf("Loading imag infile %s...", INFILE_IM ), UVM_LOW);

		infile_re = $fopen( INFILE_RE, "rb" );
		if ( !infile_re )
		begin
			`uvm_fatal("SEQ_RUN", $sformatf( "Failed to open real infile %s...", INFILE_RE ));
		end
		infile_im = $fopen( INFILE_IM, "rb" );
		if ( !infile_im )
		begin
			$fclose( infile_im );
			`uvm_fatal("SEQ_RUN", $sformatf( "Failed to open imag infile %s...", INFILE_IM ));
		end

		while ( i < N*2 ) // flush pipeline
		begin
			tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
			start_item(tx);
			if ( !$feof( infile_re ) && !$feof( infile_im ) )
			begin
				$readmemh( INFILE_RE, re );
				$readmemh( INFILE_IM, im );
				tx.re = re;
				tx.im = im;
				tx.valid = 1'b1;
			end
			//`uvm_info("SEQ_RUN", tx.sprint(), UVM_LOW);
			finish_item(tx);
			++i;
		end

		`uvm_info("SEQ_RUN", $sformatf("Closing real infile %s...", INFILE_RE), UVM_LOW);
		$fclose( infile_re );
		`uvm_info("SEQ_RUN", $sformatf("Closing imag infile %s...", INFILE_IM), UVM_LOW);
		$fclose( infile_im );
	endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;

