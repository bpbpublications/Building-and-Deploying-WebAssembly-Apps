
mod = (await WebAssembly.instantiate(await fetch('quickjs_rust.wasm ').then(r => r.arrayBuffer()), {
    wasi_snapshot_preview1: {
        clock_time_get: () => null,
        fd_close: () => null,
        proc_exit: () => null,
        environ_sizes_get: () => null,
        environ_get: () => null,
        fd_write: () => null,
        fd_seek: () => null,
        fd_fdstat_get: () => null,
        fd_prestat_get: ()=> null,
        fd_prestat_dir_name: () => null
    }
})).instance.exports;


script = 'JSON.stringify({ hello: "world"})';
ptr = mod.allocate_script(script.length);
membuffer = new Uint8Array(mod.memory.buffer);
membuffer.set(new TextEncoder().encode(script), ptr);
resultptr = mod.run_js();
membuffer = new Uint8Array(mod.memory.buffer);
new TextDecoder().decode(membuffer.slice(resultptr, membuffer.indexOf(0, resultptr)));
