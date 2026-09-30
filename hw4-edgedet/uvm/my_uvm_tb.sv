
import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

	my_uvm_if vif();

	edgedet_top #(
		.FRAME_WIDTH ( FRAME_WIDTH ),
		.FRAME_HEIGHT( FRAME_HEIGHT ),
		.COL_ID_WIDTH( COL_ID_WIDTH ),
		.ROW_ID_WIDTH( ROW_ID_WIDTH )
	) edgedet_top (
		.clk( vif.clock ),
		.rst( vif.reset ),

		.in_wr_en( vif.in_wr_en ),
		.din     ( vif.in_din ),
		.in_full ( vif.in_full ),

		.out_rd_en( vif.out_rd_en ),
		.dout     ( vif.out_dout ),
		.out_empty( vif.out_empty )
	);

	initial begin
		// store the vif so it can be retrieved by the driver & monitor
		uvm_resource_db #( virtual my_uvm_if )::set
			( .scope( "ifs" ), .name( "vif" ), .val( vif ) );

		// run the test
		run_test( "my_uvm_test" );
	end

	// clock
	initial
	begin
		#0;
		vif.clock = 1'b0;
		while ( 1'b1 )
		begin
			#( CLOCK_PERIOD/2 );
			vif.clock = ~vif.clock;
		end
	end

	// reset
	initial
	begin
		#0;
		vif.reset = 1'b0;

		@( negedge vif.clock );
		vif.reset = 1'b1;
		wait ( 10 * CLOCK_PERIOD );
		@( negedge vif.clock );
		vif.reset = 1'b0;
	end

endmodule


