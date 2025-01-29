# Chapter 8: Creating a Secure JavaScript Runtime Inside WebAssembly

# Introduction

We have just seen how we can link a simple C library into a Rust codebase and compile it to WebAssembly. In this chapter we are going to look at a more comprehensive use case. We will take QuickJS, a Javascript runtime written in C by Fabrice Bellard and Charlie Gordon, and compile it to WebAssembly. The result will be that we can run Javascript inside WebAssembly. The reason for doing this is to provide a secure runtime for hosting user supplied code. Today there are several hosting services that offers developer to upload Javascript code to be hosted in cloud, edge or blockchain environments. All of these providers need to ensure that code deployed in their hosting environments are not capable of distrupting it in any way. By hosting user supplied code inside WebAssembly containers it is possible to provide a secure sandbox, so that it is restricted in terms of capabilities and resource constraints. While the user supplied code could have been written directly in Rust, C or AssemblyScript, or another language that compiles directly to WebAssembly, Javascript is one of the most popular languages around. Javascript is also more rapid and clear on expressing pure functional behavior, compared to for example Rust that also let the developer control the lower level behavior. We also need to provide a secure way for developers that work on a higher and functional level, and providing a Javascript runtime that runs inside WebAssembly is one approach to obtain that.

The examples in this chapter are largely based on the following github repositories:

- https://github.com/petersalomonsen/quickjs-wasm-near QuickJS for WebAssembly and Javascript contracts inside Rust on NEAR protocol
- https://github.com/petersalomonsen/quickjs-rust-near Rust WebAssembly smart contract for NEAR with Javascript runtime

These repositories are showing how to compile QuickJS to WebAssembly both using Emscripten and also integrating with Rust.

# Structure

- Compiling QuickJS to WebAssembly from C
- A secure sandbox for executing user supplied code
- Linking with Rust
- Use WasmTimeCs to run a JS runtime within C#
- Adding functions to JS

# Objectives

In this chapter you will learn the purpose of executing Javascript inside WebAssembly. You will learn how to compile QuickJS to WebAssembly from C, and how you can run scripts supplied by the user in a secure way inside the WebAssembly sandbox. We will look into an example of running WebAssembly in a non-browser environment, specifically within C# using the Wasmtime WebAssembly runtime library. C and Rust have very good capabilities of interopting, and you will learn how to link QuickJS into Rust and creating a WebAssembly binary from that. In a custom Javascript runtime, we would also like to add custom functions, and you will learn how to provide such custom functions to the Javascript environment.

# Compiling QuickJS to WebAssembly from C

The first step is an easy one. QuickJS can be compiled to a static library for linking into WebAssembly binaries, without any modifications. We just need to pass some parameters in the compilation process.

Let us start by downloading QuickJS:

```bash
wget https://bellard.org/quickjs/quickjs-2024-01-13.tar.xz
tar -xf quickjs-2024-01-13.tar.xz
rm quickjs-2024-01-13.tar.xz
```

Now we have the quickjs source code in the folder named `quickjs-2024-01-13`, and we can build the static library `libquickjs.a`. If we go into this folder, we can simply issue the command `make CFLAGS_OPT='$(CFLAGS) -Oz' CC=emcc AR=emar libquickjs.a`, and we will have a static library that we can link into WebAssembly applications. We are instructing the build process to use `emcc` ( emscripten ) as a compiler, and `emar` as the archiver.

For the simple proof of concept of producing a WebAssembly library we will create a small C program that set up the Javascript runtime and have the capability to execute a script.

The C program looks like this:

```c
#include "./quickjs-2024-01-13/quickjs.h"
#include <string.h>

JSValue global_obj;
JSRuntime *rt = NULL;
JSContext *ctx;

void create_runtime()
{
    if (rt != NULL)
    {
        return;
    }
    rt = JS_NewRuntime();
    ctx = JS_NewContextRaw(rt);
    JS_AddIntrinsicBaseObjects(ctx);
    JS_AddIntrinsicDate(ctx);
    JS_AddIntrinsicEval(ctx);
    JS_AddIntrinsicStringNormalize(ctx);
    JS_AddIntrinsicRegExp(ctx);
    JS_AddIntrinsicJSON(ctx);
    JS_AddIntrinsicProxy(ctx);
    JS_AddIntrinsicMapSet(ctx);
    JS_AddIntrinsicTypedArrays(ctx);
    JS_AddIntrinsicPromise(ctx);
    JS_AddIntrinsicBigInt(ctx);

    global_obj = JS_GetGlobalObject(ctx);
}

JSValue js_eval(const char *source)
{
    create_runtime();
    int len = strlen(source);
    JSValue val = JS_Eval(ctx,
                          source,
                          len,
                          "",
                          JS_EVAL_TYPE_GLOBAL);
    return val;
}
```

The function that we will call from outside WebAssembly is `js_eval`. This function starts by calling `create_runtime` which will set up QuickJS and enable several features. We do not need to call all of these, and we can choose to only enable some features. The `create_runtime` function also takes a parameter which is a pointer to a string containing the Javascript code.

If we are going to pass a pointer to a string, we also need to allocate memory to get the pointer address. This means that the WebAssembly binary also must expose a function for allocating memory.

When we compile our Wasm module, we will include `malloc` in addition to `js_eval` for the exported functions. Our command for compiling it looks like this:

`emcc -sEXPORTED_FUNCTIONS=_js_eval,_malloc -Oz --no-entry libquickjs.a jseval.c -o jseval.wasm`

The result is a WebAssembly binary called `jseval.wasm`. 

We can use this from Javascript. It is build as a WASI module, but we can mock these functions that are imported by the Wasm module. As long as we don't use any Javascript features that would invoke any of these functions, we don't need to implement any logic in them either. 

```javascript
mod = (await WebAssembly.instantiate(await fetch('jseval.wasm').then(r => r.arrayBuffer()), {
    wasi_snapshot_preview1: {
        clock_time_get: () => null,
        fd_close: () => null,
        proc_exit: () => null,
        environ_sizes_get: () => null,
        environ_get: () => null,
        fd_write: () => null,
        fd_seek: () => null,
    }
})).instance.exports;

script = '8+5+4+3';
ptr = mod.malloc(script.length);
new Uint8Array(mod.memory.buffer).set(new TextEncoder().encode(script), ptr);
console.log(mod.js_eval(ptr));
```

After the initialization of the Wasm module, we can see the script that is just adding a few numbers. We are also calling `malloc` to allocate the bytes for the script. Then we are encoding the script string as `UTF-8` and copying it into WebAssembly memory. Finally we are ready to call `js_eval` which returns the result of executing the script.

The script in the example above is very simple. Let us make a more complex script that actually demonstrates the scripting capabilities more clearly. We should also try to return a more complex result, for example a JSON string.

Let us just modify the line in the script above that creates the Javascript we will execute through the WebAssembly module:

```javascript
script = `
let obj = { created: new Date().toJSON(), randomNumber: parseInt(Math.random() * 100), name: 'Peter' };
let message = \`This script was executed on \${new Date(obj.created)} for \${obj.name} with the random number \${obj.randomNumber}\`;
obj.message = message;
JSON.stringify(obj);
`;
```

If we now try to run this, we see that the result of `mod.js_eval` is still just a number. The difference is that it is now a pointer to the the resulting string. In order to get the string contents we need to add a new function to our C library:

```c
const char * js_get_string(JSValue val)
{
    return JS_ToCString(ctx, val);
}
```

and when we compile the C library we have to add this function to `-sEXPORTED_FUNCTIONS`:

`emcc -sEXPORTED_FUNCTIONS=_js_eval,_malloc,_js_get_string -Oz --no-entry libquickjs.a jseval.c -o jseval.wasm`

And finally in our Javascript code, we will take the pointer returned from `js_eval` and get the pointer to the string that it represents. Then we can get a slice of that particular part of memory and decode a string out of it. We detect the length of the string by searching for the first occurrence of `0` after the string pointer.

```javascript
resultptr = mod.js_eval(ptr);
resultstrptr = mod.js_get_string(resultptr);
console.log(new TextDecoder().decode(membuffer.slice(resultstrptr, membuffer.indexOf(0, resultstrptr))));
```

When we run the script we get a result like this:

```json
{"created":"1970-01-08T03:50:12.729Z","randomNumber":28,"name":"Peter","message":"This script was executed on Thu Jan 08 1970 03:50:12 GMT+0000 for Peter with the random number 28"}
```

The problem now, is that we get the same result every time we run it. We would expect the timestamp to be different, and also the random number to change for each call. The reason for this is our implementation of `clock_time_get` in the WebAssembly imports, where we return `null`. Here we should implement it according to the Wasi specification. In Wasi, `clock_time_get` writes the current time in nano-seconds to the location in memory specified by the `resultPointer` parameter being passed into the function.

We can implement it like this:

```javascript
clock_time_get: (clockId, precision, resultPointer) => {
    const timeInNanoseconds = Date.now() * 1_000_000;

    const memory = new DataView(membuffer.buffer);
    memory.setBigUint64(resultPointer, BigInt(timeInNanoseconds), true);

    return 0;
}
```

Now, when running it, we can see that we get the correct timestamp and also a different random number each time.

# A secure sandbox for executing user supplied code

The Javascript engine we now have inside WebAssembly does not have access to browser resources such as the window object, localStorage, networking. We can create a simple HTML page where the user can paste code, and we can allow running it without worrying about the user to abuse it. In some cases the user might even copy and paste code they haven't reviewed properly, and then it is important that there is some protection in the runtime environment. Executing custom scripts is an essential feature of many applications, such as spreadsheets or word processors that have macros.

Below is the code for a simple HTML page that offers the user to execute their own scripts. It is the same script as above, with the difference that we are now letting the user write the code in a text area. When clicking the run button, the result will be presented in the result area below.

```html
<!DOCTYPE html>
<html>
    <head>

    </head>
    <body>
        <h1>Write and run your own javascript</h1>
        <p>The script must return a string</p>
        <textarea id="scriptarea" style="width: 100%; height: 200px;">let obj = { created: new Date().toJSON(), randomNumber: parseInt(Math.random() * 100), name: 'Peter' };
let message = `This script was executed on ${new Date(obj.created)} for ${obj.name} with the random number ${obj.randomNumber}`;
obj.message = message;
JSON.stringify(obj);
</textarea>
        <button id="runbutton">Run</button>
        <pre style="max-width: 100%;"><code id="resultarea"></code></pre>
        <script type="module">            
            document.getElementById('runbutton').addEventListener('click', async () => {
                let membuffer;
                const mod = (await WebAssembly.instantiate(await fetch('jseval.wasm').then(r => r.arrayBuffer()), {
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

                const script = document.getElementById('scriptarea').value;            
                const ptr = mod.malloc(script.length);
                membuffer = new Uint8Array(mod.memory.buffer);
                membuffer.set(new TextEncoder().encode(script), ptr);

                const resultptr = mod.js_eval(ptr);
                const resultstrptr = mod.js_get_string(resultptr);
                document.getElementById('resultarea').innerText = new TextDecoder().decode(membuffer.slice(resultstrptr, membuffer.indexOf(0, resultstrptr)));
            });            
        </script>
    </body>
</html>
```

The script provided by the user is only able to access the capabilities that are exposed to the WebAssembly module. Currently we have only provided access to the current time. If the script for example tries to do networking, access local storage, open a window or navigate to another site, it will fail.

# Linking with Rust

QuickJS is a C library. We don't need Rust for exposing it as a WebAssembly binary, but there are use cases where linking it with Rust are relevant. For example, take the crate `ed25519_dalek` that we used for signing messages in the previous chapter. We could expose the signing functionality directltly  QuickJS, so that scripts could sign messages by just calling a simple `signMessage` function. In chapter 12, which is about smart contracts on the NEAR protocol blockchain, we will look at the Rust SDK `near-sdk-rs`. By exposing the blockchain interfaces to QuickJS, we can write smart contract functionality in JavaScript. Even with WebAssembly containers in Kubernetes, which we will discuss in chapter 13, we could benefit from writing the WebAssembly host in Rust, but still offer the possibility to embed functionality written in Javascript.

Let us start with creating a WebAssembly binary from Rust that expose QuickJS functionality. Our Rust project will have the following structure:

```
quickjs-rust/
├── Cargo.toml
├── build.rs
├── libjseval.a
├── libquickjs.a
├── src/
│   └── lib.rs
```

We have already built `libjseval.a` and `libquickjs.a` above, and we will link both of these static libraries into our Rust project. While we could integrate directly to `libquickjs.a` from Rust, the include header file `quickjs.h` contains several macros and definitions that are more easily accessible from C. By using our "intermediate" C library for initializing QuickJS and exposing the functionality we need, we will have a less complex, and more straightforward integration with Rust.

Our `build.rs` contains the linking instructions:

```rust
fn main() {
    println!("cargo:rustc-link-lib=static={}", "quickjs");
    println!("cargo:rustc-link-lib=static={}", "jseval");
    println!("cargo:rustc-link-search=native={}", ".");
}
```

Then it is the `lib.rs`, the actual implementation of our Rust project that we will build as WebAssembly:

```rust
use std::vec::Vec;

static mut SCRIPT: Option<Vec<u8>> = None;

extern "C" {
    fn js_eval(javascript_source: *const u8) -> i64;
    fn js_get_string(jsvalue: i64) -> *const u8;
}

#[no_mangle]
pub extern "C" fn siprintf(_a: i32, _b: i32, _c: i32) -> i32 {
    return 0;
}

#[no_mangle]
pub extern "C" fn allocate_script(len: usize) -> *mut u8 {
    let mut buffer = vec![0u8; len + 1];
    let ptr = buffer.as_mut_ptr();

    unsafe {
        SCRIPT.take();
        SCRIPT = Some(buffer);
    }

    ptr
}

#[no_mangle]
pub extern "C" fn run_js() -> *const u8 {
    unsafe {
        if let Some(script) = &SCRIPT {
            let js_value = js_eval(script.as_ptr());
            js_get_string(js_value)
        } else {
            "No script".as_ptr()
        }
    }
}
```

Here we are storing the script as a mutable static. A buffer for the script is allocated by calling the `allocate_script` function on the WebAssembly module, and as earlier we have to copy the script contents into the memory location returned when allocating.

We are declaring references to the functions in `libjseval.a`. We have also implemented `siprintf`. The reason for this is that otherwise it would have been declared as an import to the WebAssembly module. In this case it is just a mock implementation, and to avoid it in the WebAssembly exports, we will use `wasm_metadce` on the WebAssembly binary.

In the `run_js` function we are running the stored script, and we are also converting the result to a string value.

We can also implement a test that demonstrates how it should be invoked from the outside.

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    pub fn test_run_javascript() {
        let script = "JSON.stringify({value: 'hello'})".as_bytes();
        let script_len = script.len();
        let scriptptr = allocate_script(script_len);

        unsafe {
            let script_slice = std::slice::from_raw_parts_mut(scriptptr, script_len);
            script_slice.copy_from_slice(script);
            let result = CStr::from_ptr(run_js().cast());
            assert_eq!("{\"value\":\"hello\"}", result.to_str().unwrap());
        }
    }
}
```

Here we see the allocation of the script, and that we copy the script contents into the allocated memory. We also see that the result returned from `run_js` is a string.

Before we can use the WebAssembly module, we need to build it. We will set up our `Cargo.toml` with a release configuration for an optimized build:

```
[package]
name = "quickjs-rust"
version = "0.1.0"
authors = ["Peter Salomonsen <contact@petersalomonsen.com>"]
edition = "2018"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]

[profile.release]
lto=true
strip="symbols"
debug=false
```

And now we can build it by running `cargo build --target=wasm32-wasi --release`.

As you can see we are targeting `wasm32-wasi`, and we also have to mock this when we will consume the Wasm module later.

We can also run the tests using this command: `cargo wasi test -- --nocapture`. Like we saw in the previous chapter, this command is building a WebAssembly module for Wasi, but it is also running it in wasmtime, so that we can see the test results right away.

Before we start using the WebAssembly module, we should also do some optimizations.

First, we will use `wasm-metadce` to remove the implementation of `sprintf` from the exported methods. We will have a `meta-dce.json` only declaring the exports we want:

```json
[ 
    { 
      "name": "memory", 
      "export": "memory",
      "root": true
    },
    { 
      "name": "allocate_script", 
      "export": "allocate_script",
      "root": true
    },
    { 
      "name": "run_js", 
      "export": "run_js",
      "root": true
    }
]
```

Now we can run `wasm-metadce --enable-bulk-memory -f meta-dce.json target/wasm32-wasi/release/quickjs_rust.wasm -o quickjs_rust.wasm`.

We can also optimize it even further with the command `wasm-opt --enable-bulk-memory -c -Oz quickjs_rust.wasm -o quickjs_rust.wasm`.

Finally we can run the WebAssembly module from the browser developer tools console by pasting the following JavaScript:

```javascript
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
```

# Use wasmtime-dotnet to run a JS runtime within C#

Since we have compiled our WebAssembly module for Wasi, it is also more straightforward to use in WebAssembly runtimes that supports this. When using Wasmtime, that already provides a Wasi implementation, we don't need to mock or implement the Wasi methods as we did for the browser above. Wasmtime has implementations for several languages, and one of them is dotnet. With wasmtime-dotnet, we can use our Javascript in WebAssembly library from C#.

We start by creating a new dotnet project, and adding the Wasmtime nuget package as a dependency by typing the following commands in the terminal:

```bash
dotnet new console
dotnet add package Wasmtime --version 16.0.0
```

Then we can write our `Program.cs` file.

```csharp
using Wasmtime;

var engine = new Engine();

var module = Module.FromFile(engine, "quickjs_rust.wasm");
var linker = new Linker(engine);
linker.DefineWasi();
var store = new Store(engine);
store.SetWasiConfiguration(new WasiConfiguration());

var instance = linker.Instantiate(store, module);
var script = @"
`Hello from Javascript. Current date and time is ${new Date()}`";
var scriptptr = (int)instance.GetFunction("allocate_script").Invoke(script.Length);

var memory = instance.GetMemory("memory");
memory.WriteString(scriptptr, script);

var resultptr = (int)instance.GetFunction("run_js").Invoke();
var resultstring = memory.ReadNullTerminatedString(resultptr);
Console.WriteLine(resultstring);
```

You should also copy the `quickjs_rust.wasm` from our previous example with Rust. As you can see from the C# code it loads this WebAssembly binary into Wasmtime.

We can run the program by typing:

`dotnet run`

And as you can see it prints the message from the script along with the current date and time. Notice that in this example we use the Wasi implementation from Wasmtime. The two commands `linker.DefineWasi()` and `store.SetWasiConfiguration(new WasiConfiguration())` provides the Wasi imports to the Wasm module, including the clock implementation which makes it possible for the script to display the current date and time.

# Adding functions to JS

QuickJS allows exposing custom functions to JavaScript from the host. We can implement functions in Rust and make it possible to call them from Javascript.

To enable this, we first need to add a function to our C library:

```c
void js_add_global_function(const char *name, JSCFunction *func, int length)
{
    JS_SetPropertyStr(ctx, global_obj, name, JS_NewCFunction(ctx, func, name, length));
}
```

This function is setting a property on the Javascript global object with a function implementation that points to a C function. Now we can use this from Rust. We create an additional `init` function for this.

```rust
#[no_mangle]
pub extern "C" fn init() {
    unsafe {
        create_runtime();
        add_global_function("helloFromRust", 
            |ctx: i32, _this_val: i64, _argc: i32, _argv: i32| -> i64 {

            let result = "Hello from Rust";
            return JS_NewStringLen(ctx, result.as_ptr() as i32, result.len());
        }, 0);
    }
}
```

This adds an additional function named `helloFromRust` to our Javascript runtime, and we can now use this in the scripts we run inside QuickJS. Here's a Rust test case:

```rust
#[test]
pub fn test_custom_function() {
    init();
    let script = "helloFromRust()".as_bytes();
    let script_len = script.len();
    let scriptptr = allocate_script(script_len);

    unsafe {
        let script_slice = std::slice::from_raw_parts_mut(scriptptr, script_len);
        script_slice.copy_from_slice(script);
        let result = CStr::from_ptr(run_js().cast());
        assert_eq!("Hello from Rust", result.to_str().unwrap());
    }
}
```

Let us also try a more complex example where we add a function that takes parameters. We will implement the signing function from the previous chapter using the `ed25519_dalek` crate. We want it so that we can just write `signature = signMessage(message, signingKey)` in Javascript.

We start by adding the `ed25519_dalek` to our Rust project by typing in our terminal:

```bash
cargo add ed25519_dalek
```

In our `lib.rs` we should now add the following line in the top, to declare that we will use the newly added crate:

```rust
use ed25519_dalek::{Signer, SigningKey};
```

We also need some more functions from QuickJS. We need a function to get an array from a parameter passed as an `ArrayBuffer`, and another one for creating a new `ArrayBuffer` for the result.

We can add these two functions to our `extern "C"` section

```rust
    fn JS_GetArrayBuffer(ctx: i32, buf_len_ptr: i32, value_ptr: i64) -> *const u8;
    fn JS_NewArrayBuffer(ctx: i32, buf_ptr: i32, buf_len: i32, free_func: i32, opaque: i32, is_shared: i32) -> i64;
```

Inside the `init` method we created above, we will add another global function called `signMessage`. At the same ident as the `helloFromRust` function we can add the following:

```rust
add_global_function("signMessage", |ctx: i32, _this_val: i64, argc: i32, argv: i32| -> i64 {
    let message_argv_ptr = argv as *const i64;
    let mut message_len: usize = 0;
    let message_len_ptr: *mut usize = &mut message_len as *mut usize;

    let message_bytes: &[u8];
    let message_ptr = JS_ToCStringLen2(ctx, message_len_ptr as i32, *message_argv_ptr, 0) as *const u8;
    message_bytes = std::slice::from_raw_parts(message_ptr, message_len);

    let signing_key_argv_ptr = (argv + 8) as *const i64;
    let mut signing_key_len: usize = 0;
    let signing_key_len_ptr: *mut usize = &mut signing_key_len as *mut usize;

    let signing_key_ptr: *const [u8; 64] = JS_GetArrayBuffer(ctx, signing_key_len_ptr as i32, *signing_key_argv_ptr) as *const [u8; 64];

    let signing_key = SigningKey::from_keypair_bytes(&*signing_key_ptr).unwrap();
    let signature = signing_key.sign(message_bytes);
    let result_bytes = signature.to_bytes();            
    return JS_NewArrayBuffer(ctx, result_bytes.as_slice().as_ptr() as i32, result_bytes.len() as i32, 0, 0, 0) as i64;
}, 0);
```

The parameters from the Javascript call comes into an `argv` array. Each value in the array is 8 bytes, which represents a `JSValue` which you can find the definition of in `quickjs.h`. We use the function from QuickJS called `JS_ToCStringLen2` to convert the first parameter, a `JSValue` into a C string. The second parameter is also a `JSValue`, but for this we use `JS_GetArrayBuffer` to get the pointer to the signing key byte buffer. Note that this example does not have any checks that the function got 2 parameters and that the first is a `String`, and the second is an `ArrayBuffer`. For production use, these checks should be in place, as well as proper error handling.

After the parameters are converted into pointers, we resolve the signing key and sign the message. Finally we create a new `ArrayBuffer` from the signature bytes and return it back to Javascript.

To verify that it works as expected we can add another test method.

```rust
#[test]
pub fn test_sign_message() {
    init();
    let script = "let signatureBuffer = signMessage('hello', new Uint8Array([
        254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78,
        4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246,
        60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102,
        49, 14, 108, 234, 201, 122, 62, 159,
    ]).buffer);
    new Uint8Array(signatureBuffer).toString();".as_bytes();
    let script_len = script.len();
    let scriptptr = allocate_script(script_len);

    unsafe {
        let script_slice = std::slice::from_raw_parts_mut(scriptptr, script_len);
        script_slice.copy_from_slice(script);
        let result = CStr::from_ptr(run_js().cast());
        assert_eq!("95,215,84,162,41,169,4,227,39,241,140,48,65,236,149,58,146,109,35,77,1,85,7,44,186,226,174,250,173,210,216,163,216,35,100,178,130,13,37,8,70,150,212,194,137,40,247,7,208,108,178,192,86,219,53,104,166,51,186,100,27,15,3,3",
            result.to_str().unwrap());
    }
}
```

Here you can see a simple Javascript that calls the `signMessage` function with our message and a private key. The scripts ends with creating a string representation of the signature byte array. We verify this string in Rust as the result of the script is returned after executing it.

To really put it to the test, we should integrate it into the HTML page we made above. We can sign the message that we created from the timestamp and random number.

```html
<!DOCTYPE html>
<html>
    <head>

    </head>
    <body>
        <h1>Write and run your own javascript</h1>
        <p>The script must return a string</p>
        <textarea id="scriptarea" style="width: 100%; height: 200px;">let obj = { created: new Date().toJSON(), randomNumber: parseInt(Math.random() * 100), name: 'Peter' };
let message = `This script was executed on ${new Date(obj.created)} for ${obj.name} with the random number ${obj.randomNumber}`;
obj.message = message;
let signatureBuffer = signMessage(message, new Uint8Array([
    254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78,
    4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246,
    60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102,
    49, 14, 108, 234, 201, 122, 62, 159,
]).buffer);
obj.signature = [...new Uint8Array(signatureBuffer)];
JSON.stringify(obj, null, 1);
</textarea>
        <button id="runbutton">Run</button>
        <pre style="max-width: 100%;"><code id="resultarea"></code></pre>
        <script type="module">            
            document.getElementById('runbutton').addEventListener('click', async () => {
                const mod = (await WebAssembly.instantiate(await fetch('quickjs_rust.wasm').then(r => r.arrayBuffer()), {
                    wasi_snapshot_preview1: {
                        clock_time_get: (clockId, precision, resultPointer) => {
                            const timeInNanoseconds = Date.now() * 1000000;
                        
                            const memory = new DataView(mod.memory.buffer);
                            memory.setBigUint64(resultPointer, BigInt(timeInNanoseconds), true);
                        
                            return 0;
                        },
                        fd_prestat_dir_name: () => null,
                        fd_prestat_get: () => null,
                        fd_fdstat_get: () => null,
                        fd_close: () => null,
                        proc_exit: () => null,
                        environ_sizes_get: () => null,
                        environ_get: () => null,
                        fd_write: () => null,
                        fd_seek: () => null,
                    }
                })).instance.exports;
                mod.init();

                const script = document.getElementById('scriptarea').value;            
                const ptr = mod.allocate_script(script.length);
                let membuffer = new Uint8Array(mod.memory.buffer);
                membuffer.set(new TextEncoder().encode(script), ptr);
                const resultptr = mod.run_js();
                membuffer = new Uint8Array(mod.memory.buffer);
                const result = new TextDecoder().decode(membuffer.slice(resultptr, membuffer.indexOf(0, resultptr)));

                document.getElementById('resultarea').innerText = result;
            });            
        </script>
    </body>
</html>
```

Below is a screenshot of the user interface where the user can type a script in the text area, and we also see the result of executing it. We do now have a Javascript runtime with some functions that the browser JS environment does not have. Also this JS runtime does not have access to browser resources.

![User interface for QuickJS](test_rust.png)

# Conclusion

We can link a large selection of libraries to WebAssembly projects, and we can mix Rust and C. We have demonstrated running QuickJS inside WebAssembly, even in a non-browser environment such as a C# application. Running user supplied JavaScript inside WebAssembly is more secure, since it does not have access to browser resources without explicitly implementing support for it. When mixing Rust and C, we saw the need to implement mocks in Rust for symbols required by the C library, but we also used metadce to eliminate these from the final WebAssembly build. In this chapter we have combined the Emscripten and Rust toolchains and to build WebAssembly, and the WebAssembly Binary Toolkit for optimizing. In the next chapter we are going to go the otherway. We will create C source code from a WebAssembly binary, and use it to link for native platform targets.

# Points to remember

- Running Javascript inside WebAssembly makes it possible to run user supplied code more securely
- As with most C libraries, we need some extra glue code for exporting an interface for a WebAssembly module
- Even when linking to Rust, it might be beneficial with an extra layer of C on top of a library, depending on the complexity of the C header files. 
- With a custom Javascript like QuickJS, it is also possible to add custom functions from the C or Rust code, like the signing function from the `ed25519_dalek` crate
