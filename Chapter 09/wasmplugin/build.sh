#!/bin/bash
WASM2C=/opt/homebrew/Cellar/wabt/1.0.34/share/wabt/wasm2c   
clang -O3 -I$WASM2C -I/opt/homebrew/include instruments.c $WASM2C/wasm-rt-impl.c instrlib.c -c
ar -rcs libinstrlib.a instruments.o instrlib.o wasm-rt-impl.o
(cd build && cmake .. && cmake --build .)