#!/bin/tcsh

source /vol/eecs392/env/questasim.env

mkdir -p lib
make -f Makefile.questa dpi_lib64 LIBDIR=lib
 
vsim -do grayscale_sim.do

