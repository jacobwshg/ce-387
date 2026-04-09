#!/bin/tcsh

source /vol/eecs392/env/questasim.env

mkdir -p lib
make -f $UVM_HOME/examples/Makefile.questa dpi_lib64 LIBDIR=lib
 
	#vsim -do sim.do
	vsim -c -do sim.do

