
import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

	my_uvm_if vif();

	neuralnet_top #(
		.DATA_WIDTH( DATA_WIDTH ),
		.FRAC_WIDTH( FRAC_WIDTH ),

		.INPUT_SIZE( INPUT_SIZE ),
		.LAYER_CNT( LAYER_CNT ),
		.LAYER_SIZES( LAYER_SIZES ),

		.FIFO_DEPTH( FIFO_DEPTH )
	) nn_top_inst (
		.clk( vif.clock ),
		.rst( vif.reset ),

		.feature_in( vif.din ),
		.in_wr_en  ( vif.in_wr_en ),

		.in_full   ( vif.in_full ),
		.done      ( vif.done ),
		.label_out ( vif.dout )
	);

	initial begin
		// store the vif so it can be retrieved by the driver & monitor
		uvm_resource_db#( virtual my_uvm_if )::set(
			.scope("ifs"), .name("vif"), .val(vif)
		);

		// run the test
		run_test( "my_uvm_test" );		
	end

	// reset
	initial begin
		vif.clock <= 1'b1;
		vif.reset <= 1'b0;
		@ ( posedge vif.clock );
		vif.reset <= 1'b1;
		@ ( posedge vif.clock );
		vif.reset <= 1'b0;
	end

	// 10ns clock
	always
		#( CLOCK_PERIOD/2 )
		vif.clock = ~vif.clock;

endmodule


