

#add wave -noupdate -group my_uvm_tb
#add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

add wave -noupdate -group my_uvm_tb/fft_top_inst
add wave -noupdate -group my_uvm_tb/fft_top_inst -radix hexadecimal /my_uvm_tb/fft_top_inst/*

add wave -noupdate -group my_uvm_tb/fft_top_inst/fft_inst
add wave -noupdate -group my_uvm_tb/fft_top_inst/fft_inst -radix hexadecimal /my_uvm_tb/fft_top_inst/fft_inst/*

add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_in_inst
add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_in_inst -radix hexadecimal /my_uvm_tb/fft_top_inst/fifo_in_inst/*

add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_out_inst
add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_out_inst -radix hexadecimal /my_uvm_tb/fft_top_inst/fifo_out_inst/*

