

#add wave -noupdate -group my_uvm_tb
#add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

add wave -noupdate -group my_uvm_tb/fft_top_inst
add wave -noupdate -group my_uvm_tb/fft_top_inst -radix hexadecimal /my_uvm_tb/fft_top_inst/*

add wave -noupdate -group my_uvm_tb/fft_top_inst/fft_inst
add wave -noupdate -group my_uvm_tb/fft_top_inst/fft_inst -radix hexadecimal /my_uvm_tb/fft_top_inst/fft_inst/*

add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_in
add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_in -radix hexadecimal /my_uvm_tb/fft_top_inst/fifo_in/*

add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_out
add wave -noupdate -group my_uvm_tb/fft_top_inst/fifo_out -radix hexadecimal /my_uvm_tb/fft_top_inst/fifo_out/*

