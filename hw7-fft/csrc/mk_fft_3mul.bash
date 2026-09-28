
#!/bin/bash

EXECPATH=fft_3mul

rm -f ./$EXECPATH
clang ./fft_3mul.c -o ./$EXECPATH -lm

