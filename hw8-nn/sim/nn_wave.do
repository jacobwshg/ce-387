

#add wave -noupdate -group my_uvm_tb
#add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

add wave -noupdate -group my_uvm_tb/nn_top_inst
add wave -noupdate -group my_uvm_tb/nn_top_inst -radix hexadecimal /my_uvm_tb/nn_top_inst/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_in_l0_inst
add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_in_l0_inst -radix hexadecimal /my_uvm_tb/nn_top_inst/fifo_in_l0_inst/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l0_l1_inst
add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l0_l1_inst -radix hexadecimal /my_uvm_tb/nn_top_inst/fifo_l0_l1_inst/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l1_amax_inst
add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l1_amax_inst -radix hexadecimal /my_uvm_tb/nn_top_inst/fifo_l1_amax_inst/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/layer0_inst
add wave -noupdate -group my_uvm_tb/nn_top_inst/layer0_inst -radix hexadecimal /my_uvm_tb/nn_top_inst/layer0_inst/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/layer1_inst
add wave -noupdate -group my_uvm_tb/nn_top_inst/layer1_inst -radix hexadecimal /my_uvm_tb/nn_top_inst/layer1_inst/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/argmax_inst
add wave -noupdate -group my_uvm_tb/nn_top_inst/argmax_inst -radix hexadecimal /my_uvm_tb/nn_top_inst/argmax_inst/*

