import uvm_pkg::*;

class my_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_uvm_scoreboard)

    uvm_analysis_export #(my_uvm_transaction) sb_export_output;
    uvm_analysis_export #(my_uvm_transaction) sb_export_compare;

    uvm_tlm_analysis_fifo #(my_uvm_transaction) output_fifo;
    uvm_tlm_analysis_fifo #(my_uvm_transaction) compare_fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_export_output  = new("sb_export_output", this);
        sb_export_compare = new("sb_export_compare", this);
        output_fifo  = new("output_fifo", this);
        compare_fifo = new("compare_fifo", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_out, tx_cmp;
        
        forever begin
            compare_fifo.get(tx_cmp);
            output_fifo.get(tx_out);
            comparison(tx_cmp, tx_out);
        end
    endtask

    virtual function void comparison(my_uvm_transaction tx_cmp, my_uvm_transaction tx_out);
        if (tx_out.exp_left !== tx_cmp.exp_left || tx_out.exp_right !== tx_cmp.exp_right) begin
            `uvm_error("SB_CMP", $sformatf("FAIL | LEFT exp=%08x act=%08x | RIGHT exp=%08x act=%08x", tx_cmp.exp_left, tx_out.exp_left, tx_cmp.exp_right, tx_out.exp_right))
        end 
    endfunction
endclass