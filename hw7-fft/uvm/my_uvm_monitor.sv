
import uvm_pkg::*;

// Reads data from output fifo to scoreboard
class my_uvm_monitor_output extends uvm_monitor;
	`uvm_component_utils(my_uvm_monitor_output)

	uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

	virtual my_uvm_if vif;
	int outfile_re, outfile_im;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
			(.scope("ifs"), .name("vif"), .val(vif)));
		mon_ap_output = new(.name("mon_ap_output"), .parent(this));

		outfile_re = $fopen( OUTFILE_RE, "wb" );
		if ( !outfile_re )
		begin
			`uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open real outfile %s...", OUTFILE_RE));
		end
		outfile_im = $fopen( OUTFILE_IM, "wb" );
		if ( !outfile_im )
		begin
			$fclose( outfile_re );
			`uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open imag outfile %s...", OUTFILE_IM));
		end

	endfunction: build_phase

	virtual task run_phase(uvm_phase phase);
		int n_bytes;
		my_uvm_transaction tx_out;

		// wait for reset
		@(posedge vif.reset)
		@(negedge vif.reset)

		tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

		vif.out_rd_en = 1'b0;

		/* fetch DUT fifo output */
		for ( int i=0; i<N; )
		begin
			@(negedge vif.clock)
			begin
				if ( ~vif.out_empty )
				begin
					vif.out_rd_en = 1'b1;
					if ( vif.out_valid )
					begin
						$fwrite(outfile_re, "%h", vif.out_dout[ RE ]);
						$fwrite(outfile_im, "%h", vif.out_dout[ IM ]);
						tx_out.re = vif.out_dout[ RE ];
						tx_out.im = vif.out_dout[ IM ];
						tx_out.valid = vif.out_valid;
						mon_ap_output.write( tx_out );
						++i;
					end
				end
				else
				begin
					vif.out_rd_en = 1'b0;
				end
			end
		end
	endtask: run_phase

	virtual function void final_phase(uvm_phase phase);
		super.final_phase(phase);
		`uvm_info( "MON_OUT_FINAL", $sformatf( "Closing file %s...", OUTFILE_RE ), UVM_LOW );
		$fclose( outfile_re );
		`uvm_info( "MON_OUT_FINAL", $sformatf( "Closing file %s...", OUTFILE_IM ), UVM_LOW );
		$fclose( outfile_im );
	endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
	`uvm_component_utils(my_uvm_monitor_compare)

	uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
	virtual my_uvm_if vif;
	int cmpfile_re, cmpfile_im;
	int n_bytes;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
			(.scope("ifs"), .name("vif"), .val(vif)));
		mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

		cmpfile_re = $fopen( CMPFILE_RE, "rb" );
		if ( !cmpfile_re )
		begin
			`uvm_fatal( "MON_CMP_BUILD", $sformatf("Failed to open real cmpfile %s...", CMPFILE_RE ));
		end
		cmpfile_im = $fopen( CMPFILE_IM, "rb" );
		if ( !cmpfile_im )
		begin
			$fclose( cmpfile_re );
			`uvm_fatal( "MON_CMP_BUILD", $sformatf("Failed to open imag cmpfile %s...", CMPFILE_IM ));
		end

	endfunction: build_phase

	virtual task run_phase(uvm_phase phase);
		int n_bytes=0, i=0;
		logic signed [ DATA_WIDTH-1:0 ] re, im;
		my_uvm_transaction tx_cmp;

		// extend the run_phase 20 clock cycles
		phase.phase_done.set_drain_time(this, (CLOCK_PERIOD*20));

		// notify that run_phase has started
		phase.raise_objection(.obj(this));

		// wait for reset
		@(posedge vif.reset)
		@(negedge vif.reset)

		tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

		// synchronize file read with fifo data
		while ( !$feof( cmpfile_re ) && !$feof( cmpfile_im ) && i < N )
		begin
			@(negedge vif.clock)
			begin
				if ( ~vif.out_empty && vif.out_valid )
				begin
					$readmemh( CMPFILE_RE, re );
					$readmemh( CMPFILE_IM, im );
					tx_cmp.re = re;
					tx_cmp.im = im;
					mon_ap_compare.write( tx_cmp );
					++i;
				end
			end
		end	

		// notify that run_phase has completed
		phase.drop_objection(.obj(this));
	endtask: run_phase

	virtual function void final_phase(uvm_phase phase);
		super.final_phase(phase);
		`uvm_info("MON_CMP_FINAL", $sformatf("Closing real cmpfile %s...", CMPFILE_RE), UVM_LOW);
		$fclose( cmpfile_re );
		`uvm_info("MON_CMP_FINAL", $sformatf("Closing imag cmpfile %s...", CMPFILE_IM), UVM_LOW);
		$fclose( cmpfile_im );
	endfunction: final_phase

endclass: my_uvm_monitor_compare

