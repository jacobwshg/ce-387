
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fibonacci.sv"
vlog -work work "../sv/fibonacci_tb.sv"

vsim -classdebug -voptargs=+acc +notimingchecks -L work work.fibonacci_tb -wlf fibonacci.wlf

add wave -noupdate -group fibonacci_tb
add wave -noupdate -group fibonacci_tb -radix decimal /fibonacci_tb/*

run -all

