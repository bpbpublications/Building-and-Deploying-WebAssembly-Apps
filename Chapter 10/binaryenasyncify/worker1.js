onmessage = async function(e) {
    const port = e.data.port;

    const sharedBuffer = new SharedArrayBuffer(4);
    const sharedArray = new Int32Array(sharedBuffer);

    Atomics.store(sharedArray, 0, 0);

    const wasm = (await WebAssembly.instantiate(await fetch('sleep.wasm').then(r => r.arrayBuffer()), {
        env: {
            js_before: () => console.log('before'),
            js_after: () => console.log('after'),
            js_timeout: (duration) => {
                console.log('posting message', duration);
                port.postMessage({timeout: duration, sharedBuffer});
                Atomics.wait(sharedArray, 0, 0);
                return 54321;
            }
        }
    })).instance.exports;
    wasm.sleep(2);
}
