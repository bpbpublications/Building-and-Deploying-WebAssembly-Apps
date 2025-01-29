#!/bin/bash
../../node_modules/.bin/asc -Oz --runtime=stub --use=abort= -o tonegenerator.wasm tonegenerator.ts
wasm2c tonegenerator.wasm -o tonegenerator.c
WASM2C=/opt/homebrew/Cellar/wabt/1.0.34/share/wabt/wasm2c   
clang -O3 -I$WASM2C -I/opt/homebrew/include main.c $WASM2C/wasm-rt-impl.c tonegenerator.c -o tonegenerator