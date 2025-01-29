# Chapter 7: Writing Rust Code for WebAssembly

# Introduction

Rust is a highly popular language for creating new WebAssembly applications. It has an advanced and feature-rich toolchain that helps developers to create highly secure and efficient WebAssembly code. Rust is a low-level language in the same sense as C, but also has several features that can be found in higher level languages. A major difference from other low level languages, and also from high level languages like C# and Java, is that Rust protects the developer from making mistakes at compile time. We can say that with Rust we put more effort into making the program compile, and less in debugging. Rust may not be the most rapid development tool, but if you need to reduce the risk for regression, and introducing low level bugs, then Rust is a safe bet.

In this chapter we will focus on compiling Rust to WebAssembly, and interacting with it from Javascript. We will look into how Rust encourages test-driven approach and catching bugs at compile-time rather than when the program is running. We show a simple example of linking with a library from C, and how to optimize for size. This chapter lays the foundation for what we are going deeper into in the next chapter when linking with Rust WebAssembly the QuickJS Javascript runtime which is written in C.

# Structure

- Compiling Rust to WebAssembly
- A speed comparison with Javascript
- Reducing the risk of bugs
- Wasm-bindgen
- Linking a C library
- Testing when we have a linked C library
- Optimizing without wasm-pack

# Objectives

The purpose of this chapter is not to learn Rust, but to learn how Rust can be used to build WebAssembly applications. You will learn how Rust provides a large selection of libraries, that can be easily embedded, and also access to the large universe of C/C++ codebases. One of the most important features for providing high quality and stable applications is automatic testing. You will learn how to create unit tests, and also how to do so when having a linked C library as part of the project.

# Compiling Rust to WebAssembly

In chapter 4 we saw how we could compile a single Rust source file to WebAssembly, without setting up a project file structure. In most cases we want to create a Rust cases that depends on other libaries, and also have multiple source files. Cargo is the package manager of Rust. We can use it to define a package, or a "crate" which is the term used in Rust. The crate we define can also depend on other crates.

Let's start by creating a project file structure:

```
My_Rust_Project/
├── Cargo.toml
├── src/
│   └── lib.rs
```

Since we are targeting WebAssembly, we want to create a library in most cases. An executable with a `main` method is relevant if targeting WASI, but from the browser we will call exported functions from Javascript.

In the previous chapter we used the `tweetnacl` JavaScript library to sign tokens for authorizing with the git server. Let us implement this functionality in WebAssembly instead. In Rust we can use the `ed25519_dalek` crate, which have the same functionality. We can create a simple API on top of this library to expose as WebAssembly exports.

Let us start by declaring our crate in the `Cargo.toml` file, which contains the key info about the Rust project we are creating, and which dependencies we will be using. Here are the contents of `Cargo.toml` for this first example. 

```
[package]
name = "token-signer"
version = "0.1.0"
authors = ["Peter Salomonsen <contact@petersalomonsen.com>"]
edition = "2018"

[lib]
crate-type = ["cdylib", "rlib"]

[dependencies]
ed25519-dalek = "2.1.0"
```

As you can see this file contains the `[dependencies]` definition which references the `ed25519-dalek` crate which contains the signing functionality.

We can now create a simple API to expose to WebAssembly.

```rust
use ed25519_dalek::{Signer, SigningKey};
use std::vec::Vec;

static mut MESSAGE: Option<Vec<u8>> = None;

static mut SIGNING_KEY: [u8; 64] = [0; 64];
static mut SIGNATURE: [u8; 64] = [0; 64];

#[no_mangle]
pub extern "C" fn get_signing_key_ptr() -> *const u8 {
    unsafe { SIGNING_KEY.as_ptr() }
}

#[no_mangle]
pub extern "C" fn get_signature_ptr() -> *const u8 {
    unsafe { SIGNATURE.as_ptr() }
}

#[no_mangle]
pub extern "C" fn allocate_message(len: usize) -> *mut u8 {
    let mut buffer = vec![0u8; len];
    let ptr = buffer.as_mut_ptr();

    unsafe {
        MESSAGE = Some(buffer);
    }

    ptr
}

#[no_mangle]
pub extern "C" fn sign() {
    unsafe {
        let signing_key = SigningKey::from_keypair_bytes(&SIGNING_KEY).unwrap();
        let signature = signing_key.sign(MESSAGE.as_ref().unwrap());
        SIGNATURE.copy_from_slice(signature.to_bytes().as_slice());
    }
}
```

The `sign` function is obviously the only functionality we are interested in, but we also need a way to pass the signing key and message to it. And when the signing is done, we need to able to retrieve the result.

Since WebAssembly can only accept numbers as parameters, and also only return numbers, we need to read and write to memory and pass pointers to and from the exposed WebAssembly functions. The message can have any length, so we need to allocate memory before writing the message to it. The `allocate_message` function takes the message length in bytes as input parameter, and returns the memory address for where to write the message content. The signing key is always 64 bytes, but the client application needs to know at which memory address to write it, so this is given by the `get_signing_key_ptr` function. Finally when signing is complete, the client needs to know where to find the signature, and the pointer to this is given by the `get_signature_ptr` function.

We can build this as a WebAssembly module with the following command:

`cargo build --target=wasm32-unknown-unknown`

This results in a file called `token_signer.wasm` that we can use from Javascript:

```html
<script type="module">
const wasm = await WebAssembly.instantiate(await fetch('token_signer.wasm').then(r => r.arrayBuffer()), {});
const mod = wasm.instance.exports;

const message = 'hello';
const msg_ptr = mod.allocate_message(message.length);
const message_buffer = new Uint8Array(mod.memory.buffer, msg_ptr, message.length);
message_buffer.set(new TextEncoder('utf-8').encode(message));

const signing_key_buffer = new Uint8Array(mod.memory.buffer, mod.get_signing_key_ptr(), 64);
signing_key_buffer.set(new Uint8Array([
    254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78,
    4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246,
    60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102,
    49, 14, 108, 234, 201, 122, 62, 159,
]));
mod.sign();

const signature_buffer = new Uint8Array(mod.memory.buffer, mod.get_signature_ptr(), 64);

console.log(signature_buffer);
</script>
```

When running this, we get the signature bytes printed to the console.

Compared to JavaScript this is a lot more complex. The Rust code has more steps than JS and when consuming the library in Javascript we need to deal with low level pointers. We can immediately ask ourselves what the gain is, and the very first we can observe is a significant speed increase.

# A speed comparison with Javascript

Let us make a fair comparison here. In the comparison code below we are signing 1000 messages, first with Wasm, and then with the tweetnacl JS library. We are passing the signing key to the WebAssembly module for every message, even though we did not have to. Also we are creating the `Uint8Array` representations of the both the signature and signing key buffers, which we could have created on the outside of the loop. Since `nacl.sign.detached` takes message and signing keys as parameters, and returns the signature in a new buffer, we do the same with our Wasm loop. We pass the signing key, and we also create a copy of the returned signature to push into the resulting array.

In the end we compare the two result arrays, just to make sure that we got the same signatures.

```html
<script src="https://cdn.jsdelivr.net/npm/tweetnacl@1.0.3/nacl-fast.min.js"></script>
<script type="module">

const privateKey = new Uint8Array([254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78, 4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246, 60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102, 49, 14, 108, 234, 201, 122, 62, 159]);

const wasm = await WebAssembly.instantiate(await fetch('token_signer.wasm').then(r => r.arrayBuffer()), {});
const mod = wasm.instance.exports;

const NUM_MESSAGES = 1000;
const wasmsignatures = [];
const startTimeWasm = new Date().getTime();

for (let n = 0;n<NUM_MESSAGES;n++) {
    const message = 'hello'+n;
    const messageBytes = new TextEncoder('utf-8').encode(message);

    const msg_ptr = mod.allocate_message(message.length);
    const message_buffer = new Uint8Array(mod.memory.buffer, msg_ptr, message.length);
    message_buffer.set(messageBytes);

    const signing_key_buffer = new Uint8Array(mod.memory.buffer, mod.get_signing_key_ptr(), 64);
    signing_key_buffer.set(privateKey);
    mod.sign();

    const signature_buffer = new Uint8Array(mod.memory.buffer, mod.get_signature_ptr(), 64);
    wasmsignatures.push(signature_buffer.slice());
}
console.log('wasm time', (new Date().getTime()-startTimeWasm));

const naclsignatures = [];
const startTimeNacl = new Date().getTime();
for (let n = 0;n<NUM_MESSAGES;n++) {
    const message = 'hello'+n;
    const messageBytes = new TextEncoder('utf-8').encode(message);

    const signature = nacl.sign.detached(messageBytes, privateKey);
    naclsignatures.push(signature);
}

console.log('nacl time', (new Date().getTime()-startTimeNacl));

for (let n = 0;n<NUM_MESSAGES;n++) {
    console.assert(wasmsignatures[n].toString() == naclsignatures[n].toString(),
        n + ':\n' + wasmsignatures[n].toString() + '\n' + naclsignatures[n].toString());
}
</script>
```

The results are clear. Signing messages with the WebAssembly module is many times faster than using the tweetnacl JS library.

# Reducing the risk of bugs

Increased code complexity is often increasing the risk of bugs, and the purpose of Rust is to catch bugs early, so we have to work a bit more on justifying the use of Rust and WebAssembly in this case.

Let us look briefly into what Rust has to offer when it comes to protecting the developer from introducing bugs.

Rust has several mechanisms on the lower level, that protects the developer from leaking references outside their scope. These are complex to understand, and makes it harder to write code that compiles, compared to higher level languages that aims to solve the same problem using Garbage Collection. Still the approach of Rust will detect more developer mistakes than Garbage Collection, and it results in better performance since problems have to be solved at compile time. Cleaning up unused memory while the application is running comes with a performance cost.

The built-in testing framework is another important feature for reducing bugs. In Rust, it's easy to write tests from the very beginning. You can add unit tests to the same source file as your code, and you don't have to set up any particular test framework to get started. This way Rust encourages test-driven development out of the box, right from the start.

Let us append a test module to our `lib.rs`:

```rust
#[cfg(test)]
mod test {
    use std::slice;

    use crate::{
        allocate_message, get_signature_ptr, get_signing_key_ptr, sign,
    };

    #[test]
    pub fn test_sign() {
        let message = b"hello";

        let signing_key: [u8; 64] = [
            254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78,
            4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246,
            60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102,
            49, 14, 108, 234, 201, 122, 62, 159,
        ];
        let ptr = allocate_message(message.len());

        unsafe {
            let message_ptr = slice::from_raw_parts_mut(ptr, message.len());
            message_ptr.copy_from_slice(message);
            let signing_key_ptr = get_signing_key_ptr() as *mut u8;

            let signing_key_slice = slice::from_raw_parts_mut(signing_key_ptr, 64);
            signing_key_slice.copy_from_slice(&signing_key);

            sign();
            let expected_signature: [u8; 64] = [
                95, 215, 84, 162, 41, 169, 4, 227, 39, 241, 140, 48, 65, 236, 149, 58, 146, 109,
                35, 77, 1, 85, 7, 44, 186, 226, 174, 250, 173, 210, 216, 163, 216, 35, 100, 178,
                130, 13, 37, 8, 70, 150, 212, 194, 137, 40, 247, 7, 208, 108, 178, 192, 86, 219,
                53, 104, 166, 51, 186, 100, 27, 15, 3, 3,
            ];
            let signature_ptr = get_signature_ptr();
            let signature_slice = slice::from_raw_parts(signature_ptr, 64);

            assert_eq!(&expected_signature, signature_slice);
        }
    }
}
```

In the test function `test_sign`, we test all of the functionality. We can develop and test everything without having to package and deploy the WebAssembly module into a Javascript host environment. This speeds up development, and also significantly reduce the risk for regression in future maintenance. The approach of Rust to have the test framework integrated, and that it is so close to the code, stands out among programming languages, and improves readability and maintainability significantly. This way, developers that are new to the code, will not have to search for long to figure out how the code is supposed to work.

The test above is also written so that it use the exported functions the same way the Javascript code above does. We are allocating memory for the message, we are getting the pointers for the signing key and signature result and copying data directly to / from memory. This is also the reason we have to mark much of the code as `unsafe`, which allows us to make an exception from the memory ownership model of Rust. The memory safety features of Rust prevents many common programming errors where even higher level languages with Garbage Collection are not able to offer the same protection. Because of this, being able to write Rust code that compiles might be harder than with other languages, but this effort is rewarded in terms of fewer bugs when setting the code in production, and also reducing regression when extending it later.

When accessing the WebAssembly binary from Javascript, it would be better to have a simpler interface where we could just pass the message and signing key as parameters. Even though WebAssembly does not provide this, there is a way with Rust for better interaction with Javascript.

# Wasm-bindgen

`wasm-bindgen` is a tool for Rust that facilitates high level interactions between WebAssembly modules and JavaScript. It lets us pass and return complex types like arrays or structs, by automatically creating the Javascript glue-code. It is somehow comparable with the Javascript runtime that Emscripten provides, but with even more flexibility on type conversion.

While we can simplify our Rust code using `wasm-bindgen`, it is important to remember that not all WebAssembly hosts are JavaScript based. We have WASI, there are WebAssembly smart contract on blockchains, and we can interact with WebAssembly modules from C#, Java and other languages. Because of this, we still need to understand the approach of interacting that we provided in the first example, even though we are now going to look at a much less complex way.

With `wasm-bindgen`, we can reduce our Rust code to this:

```rust
use ed25519_dalek::{Signature, Signer, SigningKey};
use std::convert::TryInto;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn sign_message(message: &[u8], secret_key_bytes: &[u8]) -> Result<Vec<u8>, JsValue> {
    if secret_key_bytes.len() != 64 {
        return Err(JsValue::from_str("Secret key must be 64 bytes long"));
    }

    let secret_key_array: &[u8; 64] = secret_key_bytes.try_into().unwrap();

    let signing_key = SigningKey::from_keypair_bytes(secret_key_array)
        .map_err(|e| JsValue::from_str(&format!("Invalid key: {}", e)))?;

    let signature: Signature = signing_key.sign(message);

    Ok(signature.to_bytes().to_vec())
}
```

For building it, we need to use `wasm-pack`, and build for the `web` target:

`wasm-pack build --target web`

Then we can use it from Javascript:

```html
<script type="module">
import init, { sign_message } from './pkg/token_signer.js';

await init();

const message = new TextEncoder().encode('hello');
const secretKey = new Uint8Array([
    254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78,
    4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246,
    60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102,
    49, 14, 108, 234, 201, 122, 62, 159,
]);
try {
    const signature = sign_message(message, secretKey);
    console.log('Signature:', signature);
} catch (e) {
    console.error('Error:', e);
}
</script>
```

As you can see, now we have got a Javascript interface as simple to use as the one with `tweetnacl`. That is of course also because now we are not interacting directly with the WebAssembly module. The JavaScript "glue code" produced by `wasm-bindgen` does contains very much the same functionality for allocating memory for the message as we had in our example above where we invoked the WebAssembly module directly. We can see this by inspecting the `token_signer.js` file generated by `wasm-bindgen`.

Below are some essential parts of `token_signer.js`. We have the `sign_message` function that we will invoke from our client application code, and we have the `passArray8ToWasm0` which is called to allocate memory and get a pointer for where to copy the message and key data.

```javascript
function passArray8ToWasm0(arg, malloc) {
    const ptr = malloc(arg.length * 1, 1) >>> 0;
    getUint8Memory0().set(arg, ptr / 1);
    WASM_VECTOR_LEN = arg.length;
    return ptr;
}

export function sign_message(message, secret_key_bytes) {
    try {
        const retptr = wasm.__wbindgen_add_to_stack_pointer(-16);
        const ptr0 = passArray8ToWasm0(message, wasm.__wbindgen_malloc);
        const len0 = WASM_VECTOR_LEN;
        const ptr1 = passArray8ToWasm0(secret_key_bytes, wasm.__wbindgen_malloc);
        const len1 = WASM_VECTOR_LEN;
        wasm.sign_message(retptr, ptr0, len0, ptr1, len1);
        var r0 = getInt32Memory0()[retptr / 4 + 0];
        var r1 = getInt32Memory0()[retptr / 4 + 1];
        var r2 = getInt32Memory0()[retptr / 4 + 2];
        var r3 = getInt32Memory0()[retptr / 4 + 3];
        if (r3) {
            throw takeObject(r2);
        }
        var v3 = getArrayU8FromWasm0(r0, r1).slice();
        wasm.__wbindgen_free(r0, r1 * 1, 1);
        return v3;
    } finally {
        wasm.__wbindgen_add_to_stack_pointer(16);
    }
}
```

Here we see that it allocates memory for both the message and the private key, and it does also pass a pointer for the result. After calling the WebAssembly module, the signature result is copied from the memory address of the returned pointer. We can also see that the memory allocated for the result is freed when copied to the result that is returned to our client application.

In our earlier example we knew that the signature and secret keys always have the same length, and so we did not allocate memory for these. We rather declared fixed size buffers, and we save a few operations because of this, but the performance is not affected by this. If we run the speed comparison again with the module generated by `wasm-bindgen`, then it is the same as with the module we built without it.

Another thing to notice about the `wasm-bindgen` version is that we did not have to mark any sections of the code as `unsafe`. It does not mean that we don't have any unsafe sections anymore. The WebAssembly module will still pass pointers that the Javascript module use for writing directly to memory. The difference is that the `unsafe` code is provided by `wasm-bindgen`, as we can see if we study the source for the `__wbindgen_malloc` function:

```rust
pub extern "C" fn __wbindgen_malloc(size: usize, align: usize) -> *mut u8 {
    if let Ok(layout) = Layout::from_size_align(size, align) {
        unsafe {
            if layout.size() > 0 {
                let ptr = alloc(layout);
                if !ptr.is_null() {
                    return ptr
                }
            } else {
                return align as *mut u8
            }
        }
    }

    malloc_failure();
}
```

What we can learn from this, is that `wasm-bindgen` bridges the gap to Javascript when it comes to passing data that is not just the numeric primitive types. It provides the additional code needed for passing data that involves allocating memory and writing or reading directly from Javascript. In many cases we are not going to consume the WebAssembly module from Javascript, but from another runtime like Wasmtime. Maybe we are calling a WebAssembly module from within C# or Java. Even if we cannot use the Javascript code provided by `wasm-bindgen`, we can still call the WebAssembly module the same way. The Javascript code generated by `wasm-bindgen` serves as a good example for writing the glue-code to be used from other WebAssembly runtime environments.

# Linking a C library

When building with Rust, we use the same LLVM linker toolchain as with C/C++. This means we can interopt with C/C++ code quite seamlessly from Rust. We are going to look into a more comprehensive example in the next chapter when linking QuickJS from Rust, but now we will just check out the concept of linking a C library.

Let us build the C library first. A simple function that adds two integers.

```C
int add(int a, int b) {
    return a + b;
}
```

We will build it for the `wasm32` target, and as a static library.

```bash
clang -Oz --target=wasm32 -Wl,--no-entry -nostdlib -o add.o add.c
llvm-ar rc libadd.a add.o
```

Now we have a static library `libadd.a` that we can consume in our Rust project.

Our Rust project file structure looks like this.

```
My_Rust_Project/
├── Cargo.toml
├── build.rs
├── libadd.a
├── src/
│   └── lib.rs
```

Notice that in addition to `libadd.a`, we have the file `build.rs`. This file prints instructions to cargo, and in this case to include the static library in the linking process.

```rust
use std::env;
use std::path::{Path};

fn main() {
    let dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    println!("cargo:rustc-link-search=native={}", Path::new(&dir).display());
    println!("cargo:rustc-link-lib=static=add");
}
```

In our `src/lib.rs` we reference the `add` function from the static library and we use it from the function that we expose through `#[wasm_bindgen]`:

```rust
use wasm_bindgen::prelude::*;

extern "C" {
    fn add(a: i32, b: i32) -> i32;
}

#[wasm_bindgen]
pub fn add_numbers(a: i32, b: i32) -> i32 {
    unsafe {
        return add(a,b);
    }
}
```

We can now build this with `wasm-pack`:

`wasm-pack build --target web`

And we can test it in the browser with the following javascript:

```javascript
const mod = await import('./pkg/c_linked_add.js');
await mod.default();
console.log(mod.add_numbers(2,3));
```

By looking at the WebAssembly produced by `wasm-pack`, we can also see that it is highly optimized, even though it is linking a library. From looking at the final wasm, we cannot see that it has been linked at all.


```wat
(module
  (type (;0;) (func (param i32 i32) (result i32)))
  (func (;0;) (type 0) (param i32 i32) (result i32)
    local.get 0
    local.get 1
    i32.add)
  (memory (;0;) 17)
  (export "memory" (memory 0))
  (export "add_numbers" (func 0)))
```

It is worth noticing that if we had not also optimized the linked library, remember that we used the `-Oz` parameter to `clang` above, then this would also make a less optimized final WebAssembly. So all linked libraries needs to be optimized.

# Testing when we have a linked C library

Now that we have a linked C library that was compiled for the `wasm32` target, then testing using `cargo test` will fail because normally it runs for the native platform, and not WebAssembly. To get around this we have to also build our tests for the WebAssembly target. Actually we have to build the tests for the `wasm32-wasi` target, since the tests build is a comand line executable.

We can build the test executable for the `wasm32-wasi` target running the following command:

`cargo test --no-run --target=wasm32-wasi`

After the build is finished, we can find the resulting executable in the `target/wasm32-wasi/debug/deps` folder. We can the run the produced file using `wasmtime`.

`wasmtime target/wasm32-wasi/debug/deps/c_linked_add-ae4fae97d72637f0.wasm`

Running this produce the following output:

```
running 1 test
test tests::test_add_numbers ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
```

## Limitations when testing in the Wasm target

In Rust you can test if your function should "panic". `panic` is used in Rust to indicate when the program has reached the state when it can not continue, where the error is not possible to handle in any way. An issue in your linked C library can also be the source of such an error, such as if we introduce a divide function and call it so that it divides by zero. Normally we can then use the `#[should_panic]` annotation on our test function, or we can wrap the code that panics inside a `std::panic::catch_unwind` closure.

Unfortunately, with WebAssembly, such a scenario will always end the Wasm execution with an `abort` or `unreachable` instruction. When running our test code inside a WebAssembly runtime, it also means that the test will never be able to catch the panic using these methods. If we want to test if a WebAssembly function aborts as the result of a `panic` in Rust, we need to write that test code in the client environment, for example in Javascript. When called from Javascript, the WebAssembly function will throw an error, that we can catch just like any other error in Javascript.

In chapter 12, when we look into WebAssembly smart contracts on the NEAR protocol blockchain, you will see that there are tests that catch `panic!` using `std::panic::catch_unwind` closures. The difference with these tests is that they don't run inside a WebAssembly runtime. They are compiled to the native platform target. The reason why we can not compile the tests to the native platform target in this example is because we depend on a linked library that is already compiled to the `wasm` target. This will become even more clear in the next chapter where we have a larger library that we will link with Rust WebAssembly. When the whole codebase is in Rust, we can more easily and safely compile to the native platform target for running unit tests. When linking with libraries from C/C++, we can use the same library binaries for unit tests by executing the tests in a WebAssembly runtime.

# Optimizing without wasm-pack

Let us go back to the first example with signing of messages. We saw that `wasm-pack` was able to create a highly optimized wasm file with just 94kb in size. Knowing that not always a Javascript runtime might be the target for a WebAssembly module, we should also look into how to optimize without `wasm-pack`.

We can add a new `profile.release` section to our `Cargo.toml`:

```
[profile.release]
lto = true
opt-level = 'z'
debug = false
strip = 'symbols'
```

This makes a huge difference, and by this we reduce the Wasm binary size to 102K. The most important flag here is the `strip` as it removes debug info and symbols from the build. Still it is a little larger than the 94K build of `wasm-pack`, so we can try to use `wasm-opt` to optimize even further. 

The `--converge` option of `wasm-opt` will keep on optimizing as long as the previous attempt was able to reduce the size of the binary. We can use it like this:

`wasm-opt --converge -Oz target/wasm32-unknown-unknown/release/token_signer.wasm  -o token_signer.wasm`

Now we have a WebAssembly binary even smaller than the one we got from `wasm-pack`.

# Conclusion

Rust provides a solid platform for developing WebAssembly modules. It opens up for using libraries from the Rust ecosystem, and also utilizing functionality from C/C++ libraries in WebAssembly applications. The memory safety features and the built-in testing framework are essential features to build high quality and stable code. We can use `wasm-bindgen` for interoptability between Rust and Javascript, and `wasm-pack` provides highly optimized WebAssembly modules. Finally we looked at linking a simple C library into the Rust code that we build as WebAssembly, where we have a real use case in the next chapter.

# Points to remember

- Rust comes with a complete toolchain for WebAssembly
- A large selection of libraries is available in the Rust ecosystem
- We can link C/C++ libraries into our Rust projects
- `wasm-bindgen` and `wasm-pack` provides Javascript interoptability and highly optimized WebAssembly binaries
- `wasm-opt` can provide additional optimization to the binary generated from Rust
