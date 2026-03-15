

import uvm_pkg::*;

interface my_uvm_if;
    logic               clk;
    logic               rst_n;
    
    logic               iq_valid_in;
    logic               iq_ready_out;
    logic [31:0]        iq_data_in;
    
    logic signed [31:0] left_audio_out;
    logic               left_audio_valid;
    logic               left_audio_ready;
    
    logic signed [31:0] right_audio_out;
    logic               right_audio_valid;
    logic               right_audio_ready;
endinterface