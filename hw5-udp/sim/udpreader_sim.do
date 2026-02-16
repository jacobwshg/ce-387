
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/fifo_ctrl.sv"
vlog -work work "../sv/udpreader.sv"
vlog -work work "../sv/udpreader_top.sv"

# uvm library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# uvm package
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

#add wave -noupdate -group udpreader
#add wave -noupdate -group udpreader -radix decimal /udpreader/*

# start uvm simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/

#add wave -noupdate -group my_uvm_tb
#add wave -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

add wave -noupdate -group my_uvm_tb/udpreader_top_inst
add wave -noupdate -group my_uvm_tb/udpreader_top_inst -radix hexadecimal /my_uvm_tb/udpreader_top_inst/*

add wave -noupdate -group my_uvm_tb/udpreader_top_inst/reader_inst
add wave -noupdate -group my_uvm_tb/udpreader_top_inst/reader_inst -radix hexadecimal /my_uvm_tb/udpreader_top_inst/reader_inst/*


run -all

quit

