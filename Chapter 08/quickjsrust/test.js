
mod = (await WebAssembly.instantiate(await fetch('jseval.wasm').then(r => r.arrayBuffer()), {
    wasi_snapshot_preview1: {
        clock_time_get: (clockId, precision, resultPointer) => {
            const timeInNanoseconds = Date.now() * 1000000;
        
            const memory = new DataView(membuffer.buffer);
            memory.setBigUint64(resultPointer, BigInt(timeInNanoseconds), true);
        
            return 0;
        },
        fd_close: () => null,
        proc_exit: () => null,
        environ_sizes_get: () => null,
        environ_get: () => null,
        fd_write: () => null,
        fd_seek: () => null,
    }
})).instance.exports;

script = `
let obj = { created: new Date().toJSON(), randomNumber: parseInt(Math.random() * 100), name: 'Peter' };
let message = \`This script was executed on \${new Date(obj.created)} for \${obj.name} with the random number \${obj.randomNumber}\`;
obj.message = message;
JSON.stringify(obj);
`;
ptr = mod.malloc(script.length);
membuffer = new Uint8Array(mod.memory.buffer);
membuffer.set(new TextEncoder().encode(script), ptr);

resultptr = mod.js_eval(ptr);
resultstrptr = mod.js_get_string(resultptr);

console.log(new TextDecoder().decode(membuffer.slice(resultstrptr, membuffer.indexOf(0, resultstrptr))));
