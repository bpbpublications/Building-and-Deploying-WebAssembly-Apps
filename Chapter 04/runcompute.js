import { readFile } from 'fs/promises';

const wasm = await WebAssembly.instantiate(await readFile('./compute-asc.wasm'), {});
console.log('double', wasm.instance.exports.compute(0, 3));
console.log('square', wasm.instance.exports.compute(1, 3));

const boundscheckwasm = await WebAssembly.instantiate(await readFile('./boundscheck-asc.wasm'), {});
console.log('0', boundscheckwasm.instance.exports.boundscheck(0));
console.log('1', boundscheckwasm.instance.exports.boundscheck(1));
console.log('2', boundscheckwasm.instance.exports.boundscheck(2));
console.log('-2', boundscheckwasm.instance.exports.boundscheck(-2));