import uvm_pkg::*;

class my_uvm_driver extends uvm_driver#(my_uvm_transaction);
    `uvm_component_utils(my_uvm_driver)

    virtual my_uvm_if vif;
    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare; 

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
        drive();
    endtask: run_phase

    virtual task drive();
        my_uvm_transaction tx;

        wait(vif.rst_n === 1'b0);
        wait(vif.rst_n === 1'b1);

        vif.iq_data_in <= '0;
        vif.iq_valid_in <= 1'b0;
        
        vif.left_audio_ready <= 1'b1;
        vif.right_audio_ready <= 1'b1;

        forever begin
            @(negedge vif.clk) 
            begin                
                if (vif.iq_ready_out === 1'b1) begin
                    seq_item_port.get_next_item(tx);
                    
                    vif.iq_data_in <= tx.iq_data;
                    vif.iq_valid_in <= 1'b1;
                    
                    if (tx.exp_valid === 1'b1) begin
                        mon_ap_compare.write(tx);
                    end

                    seq_item_port.item_done();
                end else begin
                    vif.iq_valid_in <= 1'b0;
                    vif.iq_data_in <= '0;
                end
            end
        end
    endtask: drive
endclass