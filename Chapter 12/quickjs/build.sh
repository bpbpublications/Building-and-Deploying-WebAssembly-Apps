#!/bin/bash
#!/bin/bash
QUICKJS_ROOT=./quickjs-2024-01-13
(cd $QUICKJS_ROOT && make CFLAGS_OPT='$(CFLAGS) -Oz' CC=emcc AR=emar libquickjs.a)
cp $QUICKJS_ROOT/libquickjs.a .

emcc -sERROR_ON_UNDEFINED_SYMBOLS=0 -sEXPORTED_FUNCTIONS=_store_js,_web4_get -Oz --no-entry libquickjs.a quickjs_contract.c -o quickjs_contract.wasm