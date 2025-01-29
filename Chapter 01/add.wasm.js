const wasmbytes = new Uint8Array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 7,
    1, 96, 2, 127, 127, 1, 127, 3, 2, 1,
    0, 7, 7, 1, 3, 97, 100, 100, 0, 0,
    10, 9, 1, 7, 0, 32, 0, 32, 1, 106,
    11
]);
const adder = await WebAssembly.instantiate(wasmbytes,{}).then(mod => mod.instance.exports);
console.log(adder.add(3,5));