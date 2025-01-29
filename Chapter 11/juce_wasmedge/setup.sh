#!/bin/bash

wget https://github.com/WasmEdge/WasmEdge/archive/refs/tags/0.13.5.tar.gz
tar -xvzf 0.13.5.tar.gz

cd WasmEdge-0.13.5
cmake -Bbuild -GNinja -DCMAKE_BUILD_TYPE=Release -DWASMEDGE_LINK_LLVM_STATIC=ON -DWASMEDGE_BUILD_SHARED_LIB=Off -DWASMEDGE_BUILD_STATIC_LIB=On -DWASMEDGE_LINK_TOOLS_STATIC=On -DWASMEDGE_BUILD_PLUGINS=Off
cmake --build build
cmake --install build
cd ..
