
import uvm_pkg::*;

// Reads data from DUT to scoreboard
class my_uvm_monitor_output extends uvm_monitor;

	`uvm_component_utils( my_uvm_monitor_output )

	uvm_analysis_port #( my_uvm_transaction ) mon_ap_output;

	virtual my_uvm_if vif;

	function new( string name, uvm_component parent );
		super.new( name, parent );
	endfunction: new

	virtual function void
	build_phase( uvm_phase phase );
		super.build_phase( phase );
		void'(
			uvm_resource_db #( virtual my_uvm_if )::read_by_name(
				.scope( "ifs" ), .name( "vif" ), .val( vif )
			)
		);
		mon_ap_output = new( .name( "mon_ap_output" ), .parent( this ) );

	endfunction: build_phase

	virtual task
	run_phase( uvm_phase phase );

		int n_bytes;

		my_uvm_transaction tx_out;

		// wait for reset
		@ ( posedge vif.reset )
		@ ( negedge vif.reset )

		tx_out = my_uvm_transaction::type_id::create(
			.name( "tx_out" ), .contxt( get_full_name() )
		);

		vif.out_rd_en = 1'b0;

		/* wait for classification result from DUT and submit */
		forever
		begin
			@ ( negedge vif.clock )
			begin
				if ( vif.done )
				begin
					tx_out.label = vif.label_out;
					mon_ap_output.write(tx_out);
					break;
				end
			end
		end
	endtask: run_phase

	virtual function void
	final_phase( uvm_phase phase );
		super.final_phase( phase );
	endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
	`uvm_component_utils( my_uvm_monitor_compare )

	uvm_analysis_port #( my_uvm_transaction ) mon_ap_compare;
	virtual my_uvm_if vif;
	int cmpfile, n_bytes;

	function new( string name, uvm_component parent );
		super.new( name, parent );
	endfunction: new

	virtual function void
	build_phase( uvm_phase phase );
		super.build_phase( phase );
		void'(
			uvm_resource_db #( virtual my_uvm_if )::read_by_name(
				.scope( "ifs" ), .name( "vif" ), .val(vif)
			)
		);
		mon_ap_compare = new( .name( "mon_ap_compare" ), .parent( this ) );

		cmpfile = $fopen( CMPFILE, "rb" );
		if ( !cmpfile ) begin
			`uvm_fatal(
				"MON_CMP_BUILD", $sformatf( "Failed to open cmpfile %s...", CMPFILE )
			);
		end

	endfunction: build_phase

	virtual task
	run_phase( uvm_phase phase );
		int n_bytes = 0, i = 0;

		logic [ DATA_WIDTH-1:0 ] label_cmp;

		my_uvm_transaction tx_cmp;

		// extend the run_phase 20 clock cycles
		phase.phase_done.set_drain_time( this, ( CLOCK_PERIOD*20 ) );

		// notify that run_phase has started
		phase.raise_objection( .obj( this ) );

		// wait for reset
		@ ( posedge vif.reset )
		@ ( negedge vif.reset )

		tx_cmp = my_uvm_transaction::type_id::create(
			.name("tx_cmp"), .contxt( get_full_name() )
		);

		// synchronize file read with DUT output data
		while ( !$feof(cmpfile) ) begin
			@(negedge vif.clock)
			begin
				if ( vif.done )
				begin
					$fscanf( cmpfile, "%08d", label_cmp );
					tx_cmp.label = label_cmp;
					mon_ap_compare.write( tx_cmp );
				end
			end
		end		

		// notify that run_phase has completed
		phase.drop_objection( .obj( this ) );
	endtask: run_phase

	virtual function void
	final_phase( uvm_phase phase );
		super.final_phase( phase );
		`uvm_info(
			"MON_CMP_FINAL", $sformatf("Closing cmpfile %s...", CMPFILE),
			UVM_LOW
		);
		$fclose(cmpfile);
	endfunction: final_phase

endclass: my_uvm_monitor_compare

