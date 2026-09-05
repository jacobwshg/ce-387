
#!/bin/bash

EXECPATH=fft

rm -f ./$EXECPATH
clang ./fft_quant.c -o ./$EXECPATH -lm

