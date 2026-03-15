import uvm_pkg::*;

class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;
    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name(.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new("mon_ap_output", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_out;

        wait(vif.rst_n === 1'b0);
        wait(vif.rst_n === 1'b1);

        forever begin
            @(posedge vif.clk);
            if (vif.left_audio_valid === 1'b1 && vif.right_audio_valid === 1'b1) begin
                tx_out = my_uvm_transaction::type_id::create("tx_out", this);
                tx_out.exp_left  = vif.left_audio_out;
                tx_out.exp_right = vif.right_audio_out;
                mon_ap_output.write(tx_out); 
            end
        end
    endtask
endclass