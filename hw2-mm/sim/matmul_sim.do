
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/bram.sv"
vlog -work work "../sv/banked_bram.sv"
vlog -work work "../sv/matmul.sv"
vlog -work work "../sv/matmul_top.sv"
vlog -work work "../sv/matmul_tb.sv"

vsim \
	-classdebug \
	-voptargs=+acc +notimingchecks \
	-L work work.matmul_tb \
	-wlf matmul.wlf

add wave -noupdate -group matmul_tb
add wave -noupdate -group matmul_tb -radix decimal /matmul_tb/*

run -all

quit

