#!/bin/bash
SCRIPT_BASE64=`cat test.js| base64`
near call wasmbook.testnet --accountId=wasmbook.testnet store_js --base64 $SCRIPT_BASE64
near view wasmbook.testnet web4_get
