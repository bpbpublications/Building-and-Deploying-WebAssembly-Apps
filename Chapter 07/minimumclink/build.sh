#!/bin/bash

clang -Oz --target=wasm32 -nostdlib -c add.c
llvm-ar rc libadd.a add.o
wasm-pack build --target web
