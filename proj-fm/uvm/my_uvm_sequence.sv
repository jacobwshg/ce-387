import uvm_pkg::*;

class my_uvm_transaction extends uvm_sequence_item;
    logic [31:0] iq_data;
    logic signed [31:0] exp_left;
    logic signed [31:0] exp_right;
    bit exp_valid;

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(iq_data, UVM_ALL_ON)
        `uvm_field_int(exp_left, UVM_ALL_ON)
        `uvm_field_int(exp_right, UVM_ALL_ON)
        `uvm_field_int(exp_valid, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "");
        super.new(name);
    endfunction
endclass

class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction

    task body();
        my_uvm_transaction tx;
        int in_f, left_f, right_f;
        int in_valid, left_valid, right_valid;
        logic [31:0] file_in;
        logic signed [31:0] file_left, file_right;
        int count;

        in_f = $fopen("raw_input_iq.txt", "r");
        if (!in_f) `uvm_fatal("SEQ_RUN", "Failed to open raw_input_iq.txt");

        left_f = $fopen("output_left.txt", "r");
        if (!left_f) `uvm_fatal("SEQ_RUN", "Failed to open output_left.txt");

        right_f = $fopen("output_right.txt", "r");
        if (!right_f) `uvm_fatal("SEQ_RUN", "Failed to open output_right.txt");

        count = 0;

        while (1) begin
            in_valid = $fscanf(in_f, "%x", file_in);
            if (in_valid != 1) break;

            tx = my_uvm_transaction::type_id::create("tx");
            start_item(tx);
            
            tx.iq_data = file_in;
            tx.exp_valid = 0;

            if ((count % 8) == 7) begin
                left_valid = $fscanf(left_f, "%x", file_left);
                right_valid = $fscanf(right_f, "%x", file_right);
                
                if (left_valid == 1 && right_valid == 1) begin
                    tx.exp_left = file_left;
                    tx.exp_right = file_right;
                    tx.exp_valid = 1;
                end
            end

            finish_item(tx);
            count++;
        end

        $fclose(in_f);
        $fclose(left_f);
        $fclose(right_f);
        #310;
    endtask
endclass

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;