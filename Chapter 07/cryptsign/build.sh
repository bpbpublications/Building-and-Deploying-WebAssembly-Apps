#!/bin/bash
cargo build --target=wasm32-unknown-unknown --release
wasm-opt --converge -Oz target/wasm32-unknown-unknown/release/token_signer.wasm  -o token_signer.wasm
