import uvm_pkg::*;


class my_uvm_transaction extends uvm_sequence_item;
	logic signed [ DATA_WIDTH-1:0 ] feature = 'sh0;
	logic [ DATA_WIDTH-1:0 ] label = 'd0;

	function new( string name = "" );
		super.new( name );
	endfunction: new

	`uvm_object_utils_begin( my_uvm_transaction )
		`uvm_field_int( feature, UVM_ALL_ON )
		`uvm_field_int( label, UVM_ALL_ON )
	`uvm_object_utils_end

endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#( my_uvm_transaction );
	`uvm_object_utils( my_uvm_sequence )

	function new( string name = "" );
		super.new( name );
	endfunction: new

	task body();		
		my_uvm_transaction tx_in;

		int infile, n_bytes=0, i=0;

		logic signed [ DATA_WIDTH-1:0 ] feature;

		`uvm_info( "SEQ_RUN", $sformatf( "Loading infile %s...", INFILE ), UVM_LOW );

		infile = $fopen( INFILE, "rb" );
		if ( !infile )
		begin
			`uvm_fatal( "SEQ_RUN", $sformatf( "Failed to open infile %s...", INFILE ) );
		end

		for ( i=0; ( !$feof(infile) ) && ( i < FEATURE_CNT ); ++i )
		begin
			tx_in = my_uvm_transaction::type_id::create(
				.name("tx_in"), .contxt( get_full_name() )
			);
			start_item( tx_in );


			n_bytes = $fscanf( infile, "%08h", feature );
			tx_in.feature = feature;

			$display( "seqr sending feature %0d = %08h", i, feature );

			//`uvm_info("SEQ_RUN", tx_in.sprint(), UVM_LOW);
			finish_item( tx_in );
		end

		`uvm_info( "SEQ_RUN", $sformatf( "Closing infile %s...", INFILE ), UVM_LOW );
		$fclose( infile );
	endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;

