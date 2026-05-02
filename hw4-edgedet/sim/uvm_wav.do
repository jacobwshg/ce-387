
#add wave -noupdate -group my_uvm_tb
#add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

add wave -noupdate -group my_uvm_tb/edgedet_top
add wave -noupdate -group my_uvm_tb/edgedet_top -radix hexadecimal /my_uvm_tb/edgedet_top/*

add wave -noupdate -group my_uvm_tb/edgedet_top/gs
add wave -noupdate -group my_uvm_tb/edgedet_top/gs -radix hexadecimal /my_uvm_tb/edgedet_top/gs/*

add wave -noupdate -group my_uvm_tb/edgedet_top/sobel
add wave -noupdate -group my_uvm_tb/edgedet_top/sobel	-radix hexadecimal /my_uvm_tb/edgedet_top/sobel/*

add wave -noupdate -group my_uvm_tb/edgedet_top/sobel/fetch_stage
add wave -noupdate -group my_uvm_tb/edgedet_top/sobel/fetch_stage -radix hexadecimal /my_uvm_tb/edgedet_top/sobel/fetch_stage/*

add wave -noupdate -group my_uvm_tb/edgedet_top/sobel/compute_stage
add wave -noupdate -group my_uvm_tb/edgedet_top/sobel/compute_stage -radix hexadecimal /my_uvm_tb/edgedet_top/sobel/compute_stage/*

add wave -noupdate -group my_uvm_tb/edgedet_top/sobel/out_stage
add wave -noupdate -group my_uvm_tb/edgedet_top/sobel/out_stage -radix hexadecimal /my_uvm_tb/edgedet_top/sobel/out_stage/*

