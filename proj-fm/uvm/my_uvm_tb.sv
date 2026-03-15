import uvm_pkg::*;
import my_uvm_package::*;
import globals_pkg::*;
import quant_pkg::*;
import constants_pkg::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

    my_uvm_if vif();
    
    fm_radio_stereo dut (
        .clk(vif.clk),
        .rst_n(vif.rst_n),
        
        .iq_valid_in(vif.iq_valid_in),
        .iq_ready_out(vif.iq_ready_out),
        .iq_data_in(vif.iq_data_in),
        
        .left_audio_out(vif.left_audio_out),
        .left_audio_valid(vif.left_audio_valid),
        .left_audio_ready(vif.left_audio_ready),
        
        .right_audio_out(vif.right_audio_out),
        .right_audio_valid(vif.right_audio_valid),
        .right_audio_ready(vif.right_audio_ready)
    );

    initial begin
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));

        run_test("my_uvm_test");        
    end

    initial begin
        vif.clk <= 1'b1;
        vif.rst_n <= 1'b1;
        @(posedge vif.clk);
        vif.rst_n <= 1'b0;
        @(posedge vif.clk);
        vif.rst_n <= 1'b1;
    end

    always
        #(CLOCK_PERIOD/2) vif.clk = ~vif.clk;
        
endmodule