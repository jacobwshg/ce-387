
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/find_msb_bsrch.sv"
vlog -work work "../sv/pri_enc.sv"
vlog -work work "../sv/tb.sv"

vsim \
	-classdebug \
	-voptargs=+acc +notimingchecks \
	-L work work.msb_tb \
	-wlf msb_tb.wlf

add wave -recursive -noupdate -group msb_tb -radix hexadecimal /msb_tb/*

run -all

