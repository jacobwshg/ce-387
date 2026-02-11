
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/bram.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/sobel.sv"
vlog -work work "../sv/edge_detect_top.sv"
vlog -work work "../sv/edge_detect_tb.sv"

vsim -classdebug -voptargs=+acc +notimingchecks -L work work.edge_detect_tb -wlf edge_detect.wlf

add wave -noupdate -group edge_detect_tb
add wave -noupdate -group edge_detect_tb -radix hexadecimal /edge_detect_tb/*

add wave -noupdate -group edge_detect_tb/edge_detect_top_inst
add wave -noupdate -group edge_detect_tb/edge_detect_top_inst -radix hexadecimal /edge_detect_tb/edge_detect_top_inst/*

run -all

quit

