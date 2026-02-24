import uvm_pkg::*;


// Reads data from output fifo to scoreboard
class my_uvm_monitor_output extends uvm_monitor;
	`uvm_component_utils(my_uvm_monitor_output)

	uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

	virtual my_uvm_if vif;
	int out_file;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
			(.scope("ifs"), .name("vif"), .val(vif)));
		mon_ap_output = new(.name("mon_ap_output"), .parent(this));

	endfunction: build_phase

	virtual task run_phase(uvm_phase phase);
		int n_bytes;
		my_uvm_transaction tx_out;

		// wait for reset
		@(posedge vif.reset)
		@(negedge vif.reset)

		tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

		vif.out_rd_en = 1'b0;

		/*
 		 * receive hardware sincos from output fifo 
 		 */
		for ( int idx = -360-STAGE_CNT; idx <= 360; )
		begin
			@ (negedge vif.clock)
			begin
				if ( ~vif.out_empty )
				begin
					tx_out.sin_r = dequantize( vif.out_out[ I_SIN ] );
					tx_out.cos_r = dequantize( vif.out_out[ I_COS ] );

					mon_ap_output.write(tx_out);

					vif.out_rd_en = 1'b1;
					++idx;
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
	endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads data from compare file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
	`uvm_component_utils(my_uvm_monitor_compare)

	uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
	virtual my_uvm_if vif;
	int cmp_file, n_bytes;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
			(.scope("ifs"), .name("vif"), .val(vif)));
		mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

	endfunction: build_phase

	virtual task run_phase(uvm_phase phase);

		real rad_r = 0.0;

		my_uvm_transaction tx_cmp;

		// extend the run_phase 20 clock cycles
		phase.phase_done.set_drain_time(this, (CLOCK_PERIOD*20));

		// notify that run_phase has started
		phase.raise_objection(.obj(this));

		// wait for reset
		@(posedge vif.reset);
		@(negedge vif.reset);

		tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

		// generate software sin and cos values to compare
		for ( int deg = -360-STAGE_CNT-1; deg < 360; )
		begin
			@ (negedge vif.clock)
			begin
				if ( ~vif.out_empty ) // sync with DUT fifo sincos output
				begin
					++deg;
					/* don't sync fifo output during pipe warmup */
					if ( deg < -360 )
					begin
						continue;
					end

					rad_r = torad( deg );

					tx_cmp.deg = deg;
					tx_cmp.rad_r = rad_r;
					tx_cmp.sin_r = $sin( rad_r );
					tx_cmp.cos_r = $cos( rad_r );	
					mon_ap_compare.write(tx_cmp);
				end
			end
		end	

		// notify that run_phase has completed
		phase.drop_objection(.obj(this));
	endtask: run_phase

	virtual function void final_phase(uvm_phase phase);
		super.final_phase(phase);
	endfunction: final_phase

endclass: my_uvm_monitor_compare

