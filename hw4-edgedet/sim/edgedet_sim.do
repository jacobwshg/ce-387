
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/globals_pkg.sv"
vlog -work work "../sv/grayscale_pkg.sv"

vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/bram.sv"

vlog -work work "../sv/grayscale_pipe.sv"
vlog -work work "../sv/sobel_pipe_fetch.sv"
vlog -work work "../sv/sobel_pipe_compute.sv"
vlog -work work "../sv/sobel_pipe_output.sv"
vlog -work work "../sv/sobel_pipe.sv"

vlog -work work "../sv/edgedet_top.sv"
vlog -work work "../sv/edgedet_tb.sv"

### start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.edgedet_tb -wlf edge_detect.wlf
add wave -r -noupdate -group edgedet_tb -radix hexadecimal /edgedet_tb/*

### UVM library
#vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
#vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
#vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv
### UVM package
#vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
#vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"
### Start uvm simulation
#vsim -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/
#add wave -r -noupdate -group my_uvm_tb -radix hexadecimal /my_uvm_tb/*

run -all

quit

