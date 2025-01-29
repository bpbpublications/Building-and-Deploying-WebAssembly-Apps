import { readFile } from 'fs/promises';

const wasm = await WebAssembly.instantiate(await readFile('./3_fast_webassembly/tonegenerator.wasm'));
wasm.instance.exports.fillSampleBuffer();

const sampleBufferPos = wasm.instance.exports.samplebuffer != undefined ? wasm.instance.exports.samplebuffer.value : 1024;

console.log(new Float32Array(wasm.instance.exports.memory.buffer, sampleBufferPos, 128));