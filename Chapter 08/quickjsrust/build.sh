#!/bin/bash
QUICKJS_ROOT=./quickjs-2024-01-13
(cd $QUICKJS_ROOT && make CFLAGS_OPT='$(CFLAGS) -Oz' CC=emcc AR=emar libquickjs.a)
cp $QUICKJS_ROOT/libquickjs.a .
emcc -c jseval.c
emar -rcs libjseval.a jseval.o
emcc -sEXPORTED_FUNCTIONS=_js_eval,_js_get_string,_malloc -Oz --no-entry libquickjs.a jseval.c -o jseval.wasm
cargo build --target=wasm32-wasi --release
cargo wasi test -- --nocapture
wasm-metadce --enable-bulk-memory -f meta-dce.json target/wasm32-wasi/release/quickjs_rust.wasm -o quickjs_rust.wasm
wasm-opt --enable-bulk-memory -c -Oz quickjs_rust.wasm -o quickjs_rust.wasm
