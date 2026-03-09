
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# biases and weights
vlog -work work "../sv/biases_pkg.sv"
vlog -work work "../sv/weights_pkg.sv"
# architecture
vlog -work work "../sv/neuron_comb.sv"
vlog -work work "../sv/layer.sv"
vlog -work work "../sv/argmax.sv"
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/neuralnet_top.sv"

# uvm library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# uvm package
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

# start uvm simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/

#add waves
do ./nn_wave.do

run -all
quit

