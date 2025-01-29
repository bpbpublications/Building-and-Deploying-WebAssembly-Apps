#!/bin/bash
QUICKJS_ROOT=../../8_quickjs/quickjsrust/quickjs-2024-01-13
(cd $QUICKJS_ROOT && make CFLAGS_OPT='$(CFLAGS) -Oz' CC=emcc AR=emar libquickjs.a)
cp $QUICKJS_ROOT/libquickjs.a .
emcc -sERROR_ON_UNDEFINED_SYMBOLS=0 -sEXPORTED_FUNCTIONS=_value_return,_sleep,_sleep_callback,_malloc,_js_eval_async_module -Oz --no-entry libquickjs.a jseval.c -o jseval.wasm
