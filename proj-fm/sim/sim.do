
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

set SV_DIR "../sv"

vlog -sv -work work "$SV_DIR/globals_pkg.sv"
vlog -sv -work work "$SV_DIR/quant_pkg.sv"
vlog -sv -work work "$SV_DIR/constants_pkg.sv"
vlog -sv -work work "$SV_DIR/fifo.sv"
vlog -sv -work work "$SV_DIR/read_iq.sv"
vlog -sv -work work "$SV_DIR/add.sv"
vlog -sv -work work "$SV_DIR/sub.sv"
vlog -sv -work work "$SV_DIR/multiply.sv"
vlog -sv -work work "$SV_DIR/gain.sv"
vlog -sv -work work "$SV_DIR/fir.sv"
vlog -sv -work work "$SV_DIR/iir.sv"
vlog -sv -work work "$SV_DIR/demodulate.sv"
vlog -sv -work work "$SV_DIR/fm_radio.sv"

# uvm library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# uvm package
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

# start uvm simulation
vsim -coverage -classdebug -voptargs=+acc +notimingchecks \
     -sv_lib /vol/mentor/modelsim-2020.1/modeltech/uvm-1.2/linux_x86_64/uvm_dpi \
     work.my_uvm_tb -wlf my_uvm_tb.wlf

coverage save -onexit coverage.ucdb

do wave.do

run -all
coverage report -details -output coverage_report.txt
#quit;