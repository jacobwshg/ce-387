
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/fifo_tb.sv"

vsim -voptargs=+acc +notimingchecks -L work work.fifo_tb -wlf fifo_tb.wlf

add wave -r -noupdate -group fifo_tb -radix hexadecimal /fifo_tb/*

run -all

