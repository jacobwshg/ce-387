
alias c "clear"

setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/skidbuf.sv"
vlog -work work "../sv/findmsb_comb.sv"
vlog -work work "../sv/div_stage.sv"
vlog -work work "../sv/div_stage_group.sv"
vlog -work work "../sv/div.sv"

vlog -work work "../sv/div_tb.sv"

vsim -classdebug -voptargs=+acc +notimingchecks -L work work.div_tb -wlf brb_tb.wlf

add wave -noupdate -group div_tb
add wave -r -noupdate -group div_tb -radix hexadecimal /div_tb/*

run -all

