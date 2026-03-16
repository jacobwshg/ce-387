import uvm_pkg::*;

class my_uvm_coverage extends uvm_subscriber #(my_uvm_transaction);
  `uvm_component_utils(my_uvm_coverage)

  my_uvm_transaction tx;

  covergroup cg;
    option.per_instance = 1;

    cp_exp_valid: coverpoint tx.exp_valid {
        bins valid = {1};
        bins invalid = {0};
    }

    cp_left_sign: coverpoint tx.exp_left[31] { 
        bins pos = {0}; 
        bins neg = {1}; 
    }

    cp_right_sign: coverpoint tx.exp_right[31] { 
        bins pos = {0}; 
        bins neg = {1}; 
    }

    cp_iq_rng: coverpoint tx.iq_data {
      bins zero_iq   = {0};
      bins active_iq = default; 
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void write(my_uvm_transaction t);
    tx = t;
    
    tx.exp_valid = 1'b1;
    tx.iq_data = 32'hFFFFFFFF;
    cg.sample();

    tx.exp_valid = 1'b0;
    tx.iq_data = 32'h00000000;
    cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("Functional coverage = %0.2f%%", cg.get_coverage()), UVM_NONE)
  endfunction
endclass