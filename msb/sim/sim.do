
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/bsrch_32.sv"
vlog -work work "../sv/pri_enc.sv"
vlog -work work "../sv/tb.sv"

vsim \
	-classdebug \
	-voptargs=+acc +notimingchecks \
	-L work work.msb_tb \
	-wlf msb_tb.wlf

add wave -noupdate -group msb_tb
add wave -noupdate -group msb_tb -radix hexadecimal /msb_tb/*

add wave -noupdate -group msb_tb/bs -radix hexadecimal /msb_tb/bs/*

add wave -noupdate -group msb_tb/pe -radix hexadecimal /msb_tb/pe/*

run -all

