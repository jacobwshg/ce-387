
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/togray_comb.sv"
vlog -work work "../sv/fromgray_comb.sv"
vlog -work work "../sv/fifo_async.sv"
vlog -work work "../sv/fifo_async_tb.sv"

vsim -voptargs=+acc +notimingchecks -L work work.fifo_async_tb -wlf fifo_async_tb.wlf

add wave -r -noupdate -group fifo_async_tb -radix hexadecimal /fifo_async_tb/*

run -all

