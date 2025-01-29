import { readFile } from 'fs/promises';
const wasm = await WebAssembly.instantiate(await readFile('garbage.wasm'), {
    env: {
        abort: () => {
            console.log('abort');
        }
    }
});
console.log(wasm.instance.exports.memory.buffer.byteLength / (1024 * 1024));
