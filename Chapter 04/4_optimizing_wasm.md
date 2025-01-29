Optimizing WebAssembly for Performance and size
=================================================

# Introduction

Optimizing code execution speed and footprint improves user experience. Efficient code in realtime audio and graphics processing reduce the risk for glitches, increase the possibilities for generating rich and complex audio and video and gaming experiences. Fast optimized code improves the responsiveness in any productivity apps, such as text editors, spreadsheets, image editors and more. Fast code starts fast, and for the startup time, a smaller footprint, a small binary that loads faster than a large one.

In cloud hosting and blockchain it means lower costs, less energy usage, simply greener IT. Fast startup times also means a lot here. Being able to cold start a function when it's requested is something that we don't have with most web APIs hosted using todays docker based container technologies. A Docker container takes too long time to start in order to respond fast enough to a user request, but a WebAssembly container can be ready so fast that the user will not notice any difference to a container in standby. This means we don't need standby containers that occupies memory when not serving any request. The smaller the footprint in the Wasm container, the faster the startup time will be.

In addition to applying performant algorithms and efficient algorithms in your code, there are several tools and techniques to optimize Wasm even further. In this chapter we will look into those tools, and some real examples on using them.

# Structure

- Optimization with LLVM
- Wasm-opt: the optimizer from Binaryen
- Wasm-metadce: remove uneeded WebAssembly exports
- Considerations on including memory management features
- Connecting to Javascript math functions
- Optimizing live code in the browser
- Speed vs size optimizing

# Objectives

In this chapter you will learn how to use WebAssembly optimization tools for speed and size, and tools for removing uneeded exports and dead code. You will learn where to consider including features for memory management, and also the size/performance impact of WebAssembly frameworks or different languages. There are scenarios where speed matters, and you should learn how to prioritize for this, especially when you have to weigh the options of optimizing for size by using built-in functions in the Javascript runtime, or speed. As from the previous chapters you should learn to recognize how optimization affects the resulting WebAssembly binary, and how we can inspect that as WebAssembly Text format.

# Optimization with LLVM

When targeting WebAssembly from Rust or C you use LLVM for optimization. LLVM comes with decades of optimization evolution. We can try the `count` example from the previous chapter from Rust, and see that we get exactly the same optimization there: 

```rust
#![crate_type = "cdylib"]
#![no_std]
use core::panic::PanicInfo;
use core::arch::wasm32;

#[panic_handler]
fn handle_panic(_info: &PanicInfo) -> ! {
    wasm32::unreachable()
}

#[no_mangle]
pub extern "C" fn countto100() -> i32 {
    let mut n = 0;
    while n < 100 {
        n += 1;
    }
    n
}
```

The `#[panic_handler]` is mandatory in rust when not including the standard library ( `#![no_std]` ), even if it will not be used in this case.

Let us compile this, and for not having to create a full Rust project with a `cargo.toml`, we will just use the Rust compiler command `rustc` directly:

`rustc --target wasm32-unknown-unknown -C opt-level=z -C debuginfo=0 -C lto count.rs -o count.wasm`

Here we are telling the compiler to use full optimization for size, not to include debug info, and also use link time optimization ( `lto` ).

The resulting WAT is very similar to the one we had with C:

```
(module
  (type (;0;) (func (result i32)))
  (func $countto100 (type 0) (result i32)
    i32.const 100)
  (memory (;0;) 16)
  (global (;0;) (mut i32) (i32.const 1048576))
  (global (;1;) i32 (i32.const 1048576))
  (global (;2;) i32 (i32.const 1048576))
  (export "memory" (memory 0))
  (export "countto100" (func $countto100))
  (export "__data_end" (global 1))
  (export "__heap_base" (global 2)))
```

We can see that our counter is reduced to just the constant 100 being returned from the `countto100` function.

Let us have a look at another clever optimization of LLVM, now with C:

```c
int numbers[] = {100,200};

__attribute__((export_name("boundscheck")))
int boundscheck(int index) {
    if (index < 0 || index >= 2) {
        return -1; // Error handling for invalid index
    }
    return numbers[index];
}
```

and let us compile it:

`clang --target=wasm32 -Wl,--no-entry -nostdlib -Oz -o boundscheck.wasm boundscheck.c`

we then get the following WAT:

```
(module
  (type (;0;) (func (param i32) (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    (local i32)
    i32.const -1
    local.set 1
    local.get 0
    i32.const 1
    i32.le_u
    if (result i32)  ;; label = @1
      local.get 0
      i32.const 2
      i32.shl
      i32.const 1024
      i32.add
      i32.load
    else
      i32.const -1
    end)
  (memory (;0;) 2)
  (export "memory" (memory 0))
  (export "boundscheck" (func 0))
  (data (;0;) (i32.const 1024) "d\00\00\00\c8"))
```

Notice the result of the boundary check `if (index < 0 || index >= 2)`, which in the WAT is just:

```
local.get 0
i32.const 1
i32.le_u
```

What happens here is that we are getting the `index` parameter ( `local.get 0` ), and we are loading the constant `1`, and finally we are checking if it's less than or equal the constant ( `i32.le_u` ). So we are checking that we are less than or equal to 1, but we are in fact also checking that we are not below zero in this same expression, because we are checking from an `unsigned` point of view. A 32 bit -1 equals `0xffffffff` which is above 1 if considering as an unsigned number.

This kind of optimization we do not currently have in wasm-opt which is what AssemblyScript use.

# Wasm-opt: the optimizer from Binaryen

While Binaryen is included in both Emscripten and AssemblyScript, compiling to Wasm using LLVM from Rust or C does not include the optimizations that wasm-opt provides. Like mentioned above, with the counter and the array bounds check, LLVM provides some optimizations that we currently don't get with wasm-opt. But we also see it the other way. Additional optimization of code generated by LLVM with wasm-opt can result in even smaller and more efficient binaries. This is because wasm-opt is focused on optimizing WebAssembly, beyond the general purpose target optimization features of LLVM.

Finding a simple example of where wasm-opt can add additional optimizations is hard. While you can see a better result on larger and complex code-bases, finding a small example that highlights differences is difficult. LLVM does very good optimizations on its own, and it's not much left for wasm-opt to add to that. By focusing on WebAssembly specific scenarios we can find and example to make a point out of it.

The array bounds check example above does have optimization possibilities, even after being optimized by LLVM. It does contain redundant code.

Before optimizing with wasm-opt, `boundscheck.wasm` is 149 bytes.

We can optimize it even more with wasm-opt:

`wasm-opt boundscheck.wasm -Oz -o boundscheck-wasmopt.wasm`

And `boundscheck-wasmopt.wasm` reduces to 143 bytes.

Let us look into what the difference is between these two. After running wasm-opt, we can see that the following lines are gone:

```
(local i32)
i32.const -1
local.set 2
```

What wasm-opt did see here, that LLVM did not, was that storing the return value `-1` in a local variable, in case of providing a function index outside the bounds of the function table, is redundant. Imagine this on a larger codebase. A large Rust or C codebase will have many scenarios like this, where wasm-opt can provide additional optimizations over the already highly optimized code from LLVM.

For languages like AssemblyScript, the only optimizer is wasm-opt. And for Emscripten, it will also run wasm-opt optimizations in addition to LLVM.

We can also try writing the same program in AssemblyScript:

```typescript
const numbers: i32[] = [100,200];

export function boundscheck(index: i32): i32 {
    if (index < 0 || index >= 2) {
        return -1; // Error handling for invalid index
    }
    return numbers[index];
}
```

and compile it

`asc -Oz --runtime=stub --noExportMemory --use abort= boundscheck.ts -o boundscheck-asc.wasm`

and the boundary checking part of the WAT is then:

```
  local.get 0
  i32.const 0
  i32.lt_s
  local.get 0
  i32.const 2
  i32.ge_s
  i32.or
  if  ;; label = @1
    i32.const -1
    return
  end
```

What you see here is one check for less than zero, from a signed point of view ( `i32.lt_s` ). There's also a check for greater than or equal to 2, and there's a logical `or` operation. So a bit more than the optimization from LLVM. That said, in AssemblyScript writing additional code for this bounds check is redundant, since array bounds checking is already a part of code generated by AssemblyScript, and it is emmitted using unsigned comparison of the bounds just like LLVM does.

In fact, we could actually skip the array bounds check in AssemblyScript:

```typescript
const numbers: i32[] = [100,200];

export function boundscheck(index: i32): i32 {
    return numbers[index];
}
```

This results in a 138 byte Wasm, which is smaller than the one from C even after optimizing it additionally with wasm-opt. The built-in boundary check from AssemblyScript looks like this:

```
  local.get 0
  i32.const 76
  i32.load
  i32.ge_u
  if  ;; label = @1
    unreachable
  end
```

The array ends at memory position 76, and the bounds check is simply checking if the passed index is above this from an unsigned point of view. Just like the bounds check optimized by LLVM when compiling from C above.

From this we can learn that both LLVM and wasm-opt are powerful optimization tools. While wasm-opt does not have the legacy of LLVM, it can take advantage of WebAssembly specific optimizations. In this particular case we see that even a WebAssembly specific language like AssemblyScript can with wasm-opt, create more optimized code than LLVM.

# wasm-metadce : remove unneeded WebAssembly exports

In the examples above, and in the previous chapter we saw that both from Rust and C there were some unwanted exports. For rust we had the exports: `memory`, `__data_end` and `__heap_base`.

While we could manually edit the WAT this would be very impractical if there are more symbols. Especially when linking with other static libraries, we will often also get the exposed functions from those as exported functions in the resulting wasm.

`wasm-metadce` is a tool that can help us in removing those unwanted exports. Let's take the counter example with Rust from the beginning of this chapter. We can create a file called `meta-dce.json`, where we declare the exports we want to keep:

```json
[
  {
    "name": "countto100",
    "export": "countto100",
    "root": true
  }
]
```

And we run the command:

`wasm-metadce -f meta-dce.json count.wasm -o count.wasm`

And we end up with a WebAssembly like this:

```
(module
  (type (;0;) (func (result i32)))
  (func (;0;) (type 0) (result i32)
    i32.const 100)
  (export "countto100" (func 0)))
```

We can see now that the memory exports that we had above are gone. Also the memory section.

Let us also take an example when linking a static library from C to Rust. What is special about this use case is that the C library also calls back to Rust to get a base value, which causes the callback Rust function also to be exported to the final WebAssembly binary, which we don't want.

First we create a simple c static library:

```c
extern int getBaseValue();

int add(int a, int b) {
    return getBaseValue() + a+b;
}
```

`clang --target=wasm32 -Oz -c -o add.o add.c`

and make a static library:

`llvm-ar rcs libadd.a add.o`

and create a Rust program that use it:

```rust
#![crate_type = "cdylib"]
#![no_std]
use core::panic::PanicInfo;
use core::arch::wasm32;

#[panic_handler]
fn handle_panic(_info: &PanicInfo) -> ! {
    wasm32::unreachable()
}

extern "C" {
    fn get_base_value() -> i32;
}

extern "C" {
    fn add(a: i32, b: i32) -> i32;
}

#[no_mangle]
pub extern "C" fn getBaseValue() -> i32 {
    unsafe {
        return get_base_value();
    }
}

#[no_mangle]
pub extern "C" fn useadd(a: i32, b: i32) -> i32 {
    unsafe {
        return add(a,b);
    }
}
```

Now use the Rust compiler, linking the static library, with link time optimizations.

`rustc --target wasm32-unknown-unknown -L . -l static=add -C opt-level=z -C debuginfo=0 -C lto useadd.rs -o useadd.wasm`

Now, in `useadd.wasm`, we see that we have `getBaseValue` as an export, but we only wanted to use that function internally. We can then use `wasm-metadce` to remove it. Our `wasm-metadce.json` needs to contain the exports we want to keep:

```json
[
   {
        "name": "useadd",
        "export": "useadd",
        "root": true
    }
]
```

After editing the json file containing the exports we want, we can run `wasm-metadce`:

`wasm-metadce -f meta-dce.json useadd.wasm -o useadd.wasm`

And now we only have the one import and export that we wanted:

```
(module
  (type (;0;) (func (param i32 i32) (result i32)))
  (type (;1;) (func (result i32)))
  (import "env" "get_base_value" (func (;0;) (type 1)))
  (func (;1;) (type 0) (param i32 i32) (result i32)
    local.get 0
    local.get 1
    call 3)
  (func (;2;) (type 1) (result i32)
    call 0)
  (func (;3;) (type 0) (param i32 i32) (result i32)
    local.get 1
    local.get 0
    i32.add
    call 2
    i32.add)
  (export "useadd" (func 1)))
```

Notice that this could be optimized even more. The two nested function calls could be reduced to just calling the imported function. We can run `wasm-opt` for the final touch here:

`wasm-opt --converge -Oz  useadd.wasm -o useadd.wasm`

which results in the follow WAT:

```
(module
  (type (;0;) (func (result i32)))
  (type (;1;) (func (param i32 i32) (result i32)))
  (import "env" "get_base_value" (func (;0;) (type 0)))
  (func (;1;) (type 1) (param i32 i32) (result i32)
    call 0
    local.get 0
    local.get 1
    i32.add
    i32.add)
  (export "useadd" (func 1)))
```

We have now obtained to use Rust and C that calls each other, and we eliminated the exports of functions that were only supposed to be used internally. A real use case of this is when embedding QuickJS into a Rust codebase targeting WebAssembly. Then we first use `wasm-metadce` to remove unwanted exports, and finally `wasm-opt` for optimization.

# Considerations on including memory management features

We have been looking into real time applications for generating audio. In such a scenario we can reserve all the memory we need up front. We don't need to free up memory while the program is running, and certainly we don't need garbage collection. In languages like Java, if using it for implementing a software synthesizer, garbage Collection will cause glitches in the sound output. By using AssemblyScript compiled to WebAssembly, we can avoid the garbage collection.

Another scenario where we might not need to worry so much about cleaning up memory, is short lived functions served in cloud or edge computing. When implemented as WebAssembly modules, these functions can start, serve the request, and be teared down. In many cases there is no need to free memory while it's running. The same goes for WebAssembly smart contracts running on a blockchain. Smart contract calls are short-lived. The WebAssembly module is instantiated when called, and teared down when the call has finished.

For long running applications, operating on file systems, processing large databuffers, involved in network traffic etc, we need to free up memory along the way. We might also need Garbage Collection. Wasm-git, which we are going to look into in a later chapter, operates on files and communicates over the network. Large buffers are being allocated and freed many times during the lifespan of the application. Wasm-git is a port of libgit2 to WebAssembly, and makes it possible to have a full featured git client in the browser. Libgit2 is written in C, and has its own memory management, so there is no garbage collection, which is not typical for a C application either. But such applications are typical candidates for taking advantage of Garbage Collection. If implementing an app in AssemblyScript, that would process files and network traffic, enabling the Garbage Collector would be beneficial.

In the time of writing this book, WebAssembly Garbage Collection (WasmGC) is being enabled by default in Chromium browsers. This opens up for applications written in languages that use Garbage Collection, such as Kotlin, Java, PHP and more. It means that the added size of a garbage collector inside the WebAssembly binary is not needed anymore. While Garbage Collection then will not cause any overhead when it comes to size, it is still important to consider if it's beneficial for performance.

# Connecting to Javascript math functions

Javascript comes with a built-in Math library, and it is possible to use this from WebAssembly. 

For example if we have this program in AssemblyScript:

```typescript
declare function sin(angle: f32): f32;
declare const PI: f32;

const SAMPLE_BUFFER_START = 1024;
const SAMPLE_BUFFER_END = 1024 + 128 * 4;

const SAMPLERATE: f32 = 44100;
const step: f32 = 440 / SAMPLERATE;
let angle: f32 = 0;

export function fillSampleBuffer(): void {
    for (let n=SAMPLE_BUFFER_START;n<SAMPLE_BUFFER_END;n+=4) {
        angle += step;
        const samplevalue = sin(angle * PI * 2);
        store<f32>(n, samplevalue);
    }
}
```

Here we declare `sin` and `PI` as and imported function and constant, and if we compile this

`asc -Oz --initialMemory=1  sinetonegenerator.ts -o sinetonegenerator.wasm`

We can see that the resulting WebAssembly contains two imports:

```
(import "sinetonegenerator" "sin" (func (;0;) (type 0)))
(import "sinetonegenerator" "PI" (global (;0;) f32))
```

If we want to call this WebAssembly module from JavaScript we need to provide imports for `sin` and `PI`, and we will provide the built-in functions of Javascript here:

```javascript
wasmmodule = await WebAssembly.instantiate(await fetch('sinetonegenerator.wasm').then(r => r.arrayBuffer()), {
  sinetonegenerator: {
    sin: Math.sin,
    PI: Math.PI
  }
});

startTime = new Date().getTime();
for (let n=0;n<100000;n++) {
  wasmmodule.instance.exports.fillSampleBuffer();
}
console.log('duration milliseconds', (new Date().getTime()-startTime));
```

The WebAssembly module is just 183 bytes, but notice that we will now also check the speed of he execution. We are measuring the number of milliseconds it takes to call `fillSampleBuffer` 100,000 times. A measurement taken from a Macbook Air M1 machine is 463 milliseconds.

Now we will try to not use the Math functions from Javascript and instead use WebAssembly implementations of these.

```typescript
const SAMPLE_BUFFER_START = 1024;
const SAMPLE_BUFFER_END = 1024 + 128 * 4;

const SAMPLERATE: f32 = 44100;
const step: f32 = 440 / SAMPLERATE;
let angle: f32 = 0;

export function fillSampleBuffer(): void {
    for (let n=SAMPLE_BUFFER_START;n<SAMPLE_BUFFER_END;n+=4) {
        angle += step;
        const samplevalue = Mathf.sin(angle * Mathf.PI * 2);
        store<f32>(n, samplevalue);
    }
}
```

If we run this from Javascript, using the following code, where we don't provide imports:

```typescript
wasmmodule = await WebAssembly.instantiate(await fetch('nativemathfsinetonegenerator.wasm').then(r => r.arrayBuffer()), {});

startTime = new Date().getTime();
for (let n=0;n<100000;n++) {
  wasmmodule.instance.exports.fillSampleBuffer();
}
console.log('duration milliseconds', (new Date().getTime()-startTime));
```

Now we see on the same machine that the duration for calling `fillSampleBuffer` 100,000 times is 132 milliseconds. 132 vs 463 is 3.5 times faster. The WebAssembly file size is now 745 bytes compared to 183, so the size has increased, but this is only an increase of the base size, for the implementation of the Math function. For real-time applications the speed gain is what matters here, and we should consider accepting the increased size.

# Optimizing live code in the browser

In the previous chapter, we demonstrated live compiling to WebAssembly in the browser. If you look closer at the compiler invocation, you can see that the parameters for optimization are not turned on. This is because we want an instant result when live coding. The optimization passes of `wasm-opt` takes extra time, and the live-coding experience would not be so responsive if we had to wait a few seconds to hear the result of each edit.

In the following example, the optimization time is not a big issue, since the code we are going to compile is quite small. Still you can see that the amount of extra time spent when turning on optimization is significant. Also notice that the AssemblyScript code is using a `StaticArray` instead of `store<u8>` directly. Optimization is more noticable when we are using the features of the programming language, compared to trying to write as low level as possible. By using the language features to write more structured and readable code, we also enable the optimizer to do its job.

Below are the screenshots of a live image generator in the browser. It generates a WebAssembly module that takes the current time in Milliseconds as input, and renders an image based on that. The WebAssembly module is written in AssemblyScript, which we can edit and compile directly from the browser. We can compile either unoptimized, or optimized. The unoptimized version use a bit more time to render each frame, and also has a larger binary size, while the optimized takes longer time to compile.

Unoptimized version:

![](./canvaslivecodeunoptimized.png)

Optimization turned on:

![](./canvaslivecode1optimized.png)

Here is also the full source code, in a single HTML file. We have a textarea containing the AssemblyScript source code. There's a canvas element where the image data is rendered, and then there is the Javascript code that calls the AssemblyScript compiler and runs the WebAssembly module to generate image data and copy it into the canvas.

```html
<!DOCTYPE html>
<html>

<head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
</head>

<body>
    <canvas id="myCanvas"></canvas>
    <textarea id="codearea" width="" style="width: 100%; height: 250px">
const WIDTH = 500;  
const HEIGHT = 250;

export const imagebuffer: StaticArray<u8> = new StaticArray<u8>(WIDTH * HEIGHT * 4);

export function draw(time: i32): void {
    let index = 0;
    for (let y: i32 = 0; y < HEIGHT; y++) {
        for (let x: i32 = 0; x < WIDTH; x++) {
            const r: u8 = (Math.sin(Math.PI * 2 * ((time+x*8) / 1000.0)) * 127 + 128) as u8;
            const g: u8 = (Math.sin(Math.PI * 2 * ((time-y*4) / 1000.0)) * 127 + 128) as u8;
            const b: u8 = (Math.cos(Math.PI * 2 * ((time-x*10+y*5) / 1000.0)) * 127 + 128) as u8;

            imagebuffer[index++] = r;
            imagebuffer[index++] = g;
            imagebuffer[index++] = b;
            imagebuffer[index++] = 255;
        }
    }
}            
    </textarea>
    <button id="compileandrunbutton">Compile and run</button>
    <button id="compileandrunoptimizedbutton">Compile, optimize and run</button>
    <p>
        Frame render time: <span id="framerendertime"></span> ms<br />
        Compile time: <span id="compiletime"></span> ms<br />
        Wasm size: <span id="wasmsize"></span> bytes<br />
    </p>
    <p>
    <pre><code id="erroroutput"></code></pre>
    </p>
</body>
<script src="https://cdn.jsdelivr.net/npm/assemblyscript@0.27.14/dist/web.js"></script>
<script type="module">
    import asc from "assemblyscript/asc";
    let drawFunction = () => null;

    const canvas = document.getElementById('myCanvas');
    const ctx = canvas.getContext('2d');
    const width = 500;
    const height = 250;
    canvas.width = width;
    canvas.height = height;

    const drawLoop = () => {
        const drawStartTime = new Date().getTime();
        drawFunction(drawStartTime);
        document.getElementById('framerendertime').innerHTML = (new Date().getTime() - drawStartTime);

        requestAnimationFrame(() => drawLoop());
    }
    drawLoop();

    async function compileAndRun(optimize = false) {
        drawFunction = () => null;

        const erroroutput = document.getElementById('erroroutput');
        const output = {};
        const sources = {
            "imagegenerator.ts": document.getElementById('codearea').value
        }
        erroroutput.innerHTML = '';
        const compileStartTime = new Date().getTime();
        const { error, stdout, stderr, stats } = await asc.main([
            "--runtime", "stub",
            "--use", "abort=",
            optimize ? "-Os" : "-O0",
            "--initialMemory", "100",
            "imagegenerator.ts",
            "--outFile", "imagegenerator.wasm",
        ], {
            readFile: name => sources.hasOwnProperty(name) ? sources[name] : null,
            writeFile: (name, contents) => output[name] = contents,
            listFiles: () => []
        });
        if (error) {
            erroroutput.innerText = stderr.toString();
        }

        const wasmbinary = output['imagegenerator.wasm'].buffer;
        const wasmModule = await WebAssembly.instantiate(wasmbinary, {});
        const { draw, imagebuffer, memory } = wasmModule.instance.exports;

        document.getElementById('compiletime').innerHTML = (new Date().getTime() - compileStartTime);
        document.getElementById('wasmsize').innerHTML = wasmbinary.byteLength;

        drawFunction = (drawStartTime) => {
            const imageData = ctx.createImageData(width, height);

            draw(drawStartTime);
            const wasmBytes = new Uint8Array(memory.buffer, imagebuffer, width * height * 4);
            imageData.data.set(wasmBytes);

            ctx.putImageData(imageData, 0, 0);
        }
    }
    document.getElementById('compileandrunoptimizedbutton').addEventListener('click', () => compileAndRun(true));
    document.getElementById('compileandrunbutton').addEventListener('click', () => compileAndRun());
</script>

</html>
```

This is a minimalistic, but complete live coding environment for an image animation generator. It will also give you feedback on the errors from the AssemblyScript compiler, just like the live coding example for audio in the previous chapter.

# Speed vs size optimizing

We can increase speed by using more memory and more space. Code inlining, will reduce branching, and then increase speed. Pre-computing frequently looked up data does increase performance significantly, but also increase the binary size. 

When we are later going to look into compiling the libgit2 library, creating blockchain smart contracts, or cloud / edge functions, we will focus on size. This is because we want load and startup to be as fast as possible. For realtime experiences, such as the audio and visual examples we have seen so far, speed is what matters the most.

Both Binaryen and LLVM has the optimization option focusing on size `-Oz` and speed `-Os`. Speed optimization will inline functions, meaning you will see the same function code repeated where it is used. It will also "unroll" loops, which means that rather than loop statements, codeblocks will just be repeated. It will pre-compute constants and frequently looked up data. Size optimization will focus on the opposite, and try to repeat as little as possible.

# Conclusion

Just like optimization features have been available for C compilers for decades, we can also use the same when targeting WebAssembly. In addition there are optimization tools as part of the WebAssembly toolchain, that will help us in optimizing the Wasm code, and also eliminating dead code. Optimizing for size can sacrifice speed and vice versa, and optimization features can also affect user experience in a live coding environment. Optimization always needs careful consideration and testing for the particular application use case.

# Points to remember

- Optimization features of LLVM and Binaryen
- How to use wasm-metace for elimitating dead code
- The performance impact of calling Javascript functions from Wasm
- Live coding and optimization considerations when it comes to compile time vs performance