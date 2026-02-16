
import uvm_pkg::*;
import my_uvm_package::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

	my_uvm_if vif();

	udpreader_top #(
	) udpreader_top_inst (
		.clock( vif.clock ),
		.reset( vif.reset ),

		.in_we ( vif.in_wr_en ),
		.in_din( vif.in_din ),
		.in_sof_in( vif.in_sof_in ),
		.in_eof_in( vif.in_eof_in ),
		.out_re( vif.out_rd_en ),

		.in_full  ( vif.in_full ),
		.out_empty( vif.out_empty ),
		.out_dout ( vif.out_dout ),
		.out_sof_out( vif.out_sof_out ),
		.out_eof_out( vif.out_eof_out ),

		.pkt_done( vif.pkt_done ),
		.sum_true( vif.sum_true )
	);


	initial begin
		// store the vif so it can be retrieved by the driver & monitor
		uvm_resource_db#(virtual my_uvm_if)::set
			(.scope("ifs"), .name("vif"), .val(vif));

		// run the test
		run_test("my_uvm_test");
	end

	// reset
	initial
	begin
		vif.clock <= 1'b1;
		vif.reset <= 1'b0;
		@(posedge vif.clock);
		vif.reset <= 1'b1;
		@(posedge vif.clock);
		vif.reset <= 1'b0;
	end

	// 10ns clock
	always
	begin
		#(CLOCK_PERIOD/2) vif.clock = ~vif.clock;
	end

endmodule: my_uvm_tb

