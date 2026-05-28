

#add wave -noupdate -group my_uvm_tb
#add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

add wave -noupdate -group my_uvm_tb/nn
add wave -noupdate -group my_uvm_tb/nn -radix hexadecimal /my_uvm_tb/nn/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_in_l0
add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_in_l0 -radix hexadecimal /my_uvm_tb/nn/fifo_in_l0/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l0_l1
add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l0_l1 -radix hexadecimal /my_uvm_tb/nn/fifo_l0_l1/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l1_amax
add wave -noupdate -group my_uvm_tb/nn_top_inst/fifo_l1_amax -radix hexadecimal /my_uvm_tb/nn/fifo_l1_amax/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/l0
add wave -noupdate -group my_uvm_tb/nn_top_inst/l0 -radix hexadecimal /my_uvm_tb/nn/l0/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/l1
add wave -noupdate -group my_uvm_tb/nn_top_inst/ll -radix hexadecimal /my_uvm_tb/nn/l1/*

add wave -noupdate -group my_uvm_tb/nn_top_inst/argmax
add wave -noupdate -group my_uvm_tb/nn_top_inst/argmax -radix hexadecimal /my_uvm_tb/nn/argmax/*

