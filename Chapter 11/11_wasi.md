# Chapter 11: WebAssembly Runtimes and WASI, Interacting with the Operating System

# Introduction

WASI, the WebAssembly System Interface, is a gateway for WebAssembly to access operating system resources. And when not running in the browser, we can use standalone WebAssembly runtimes that are designed to run either as a CLI application or for embedding into a custom application. There are several WebAssembly runtime implementations that facilitates running Wasm in a non-browser environment. The bytecode format of WebAssembly is efficient and secure for providing portable code plugins in all kinds of applications, and by embedding a WebAssembly runtime we can achieve that.

We have already seen how we can convert WebAssembly to C for embedding into other C/C++ applications. Embedding a Wasm runtime can save us from having to convert the Wasm module beforehand, we can use the module as it is, without loosing noticable performance. From the security perspective we also saw in chapter 8 how we can include a Javascript engine inside C#, by using Wasmtime.NET to run QuickJS compiled to WebAssembly.

We did also look into some WASI examples in previous chapters, demonstrating interaction with files and standard output. We will revisit this briefly here, but also look further into the evolution of WASI. The first preview of WASI has several limitations, and there are several initiatives to mitigate this gap, including an ongoing standardization process. In this chapter you will see some examples from the various alternatives, and how to use the WebAssembly runtimes outside the browser. 

# Structure

- Hello WASI
- Emscripten and the wasi-sdk
- Beyond the capabilities of WASI preview 1
- WASIX
- WASI Preview 2 and the WebAssembly Component Model
    - Combining components written in different languages
- WasmEdge, embedding WebAssembly into native applications

# Objectives

In this chapter you will learn how to implement using basic system operation features by the capabilities of WASI preview 1. We will look into how Emscripten and Wasmer offers alternatives to bridge the gaps of missing features. You will get an introduction to WASI preview 2 and the WebAssembly Component Model. Throughout the chapter various WebAssembly runtimes will be used, started from the command-line interface, and also embedded into a native application.

# Hello WASI

In chapter 5, we had a similar example in C, that we compiled using Emscripten. Now we will see what a simple program that writes "hello" to the terminal output looks like from the WebAssembly Text Format.

```
(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (func (export "_start")
    i32.const 1
    i32.const 0
    i32.const 1
    i32.const 100
    call $fd_write
    drop
  )
  (memory (export "memory") 1)
  (data (i32.const 0) "\08\00\00\00\07\00\00\00hello\n\00")
)
```

To try this we can use `wat2wasm` to convert it into a Wasm binary:

`wat2wasm hello.wat -o hello.wasm`

And then we can run this with a WebAssembly runtime.

For example Wasmtime:

`wasmtime hello.wasm`

or Wasmer:

`wasmer hello.wasm`.

Both of them will output the string "hello".

As you can see, the actual printing to stdout is provided by the imported function `fd_write`. We are providing it with parameters, where the first is the file descriptor of stdout, which is `1`. The second is a pointer to where in memory to find the `iovec` structure, which in this example have set to memory address `0`. The third parameter says how many `iovec` structures we have which is `1`. The `iovec` structure itself can be found in the `data` section, where the first 4 bytes point to the memory address of the content, and the next 4 bytes contains the content length. We are pointing to address `8` and a content length of `7` bytes, which then contains `hello\n\0`. The word followed by newline and null termination. The last parameter to `fd_write` is a memory address where it can output the number of bytes actually written, which we set to `100` in this example.

`fd_write` is one of many standard functions defined in the WASI spec, which resembles POSIX, the standard API in Linux and Unix operating systems. It is however quite limited compared to the full POSIX specification, since it is still in its early stages of evolution, and so there are parallell initiatives to mitigate this for real world use cases. Because of the promise of WebAssembly to focus on both portability and security, there is no intention to fully implement POSIX. Still there is a demand to be able to have WebAssembly code accessing file, networking and multi-threading operations like native apps. There are several ongoing initiatives of development in the WebAssembly ecosystem to achieve this, and yet preserve the intentions of a secure and portable runtime specification and binary format.

Let us look into how Emscripten and the wasi-sdk handles code that use operating system features.

# Emscripten and the wasi-sdk

In chapter 5, we saw how Emscripten is capable of compiling a WASI application that prints `hello` to the standard output. Let us take it a bit further, by creating program that lists files in the current directory.

```c
#include <dirent.h> 
#include <stdio.h> 

int main(void) {
  DIR *d;
  struct dirent *dir;
  d = opendir(".");
  if (d) {
    while ((dir = readdir(d)) != NULL) {
      printf("%s\n", dir->d_name);
    }
    closedir(d);
  }
  return(0);
}
```

If we try to compile this with Emscripten by typing:

```bash
emcc listfiles.c -o listfiles.wasm 
```

and try running it using wasmtime:

```bash
wasmtime --dir .::. listfiles.wasm
```

then we see the error message:

```
 1: unknown import: `env::__syscall_getdents64` has not been defined
```

If convert the wasm to wat using `wasm2wat listfiles.wasm -o listfiles.wat`, then we see that `listfiles.wat` contains the following line:

```
(import "env" "__syscall_getdents64" (func (;2;) (type 1)))
```

This is not according to the WASI specification, but rather targeting the Emscripten Javascript API. When running with `wasmtime` from the command line, we do not have `__syscall_getdents64` imported into the Wasm instance, and so it will not be able to run. If using the wasmtime library as part of a custom application, we could have implemented this function ourselves, but still it is not the ideal approach trying to mimic the Emscripten JS API.

The `wasi-sdk` can help us here. You can find it at https://github.com/WebAssembly/wasi-sdk. The `wasi-sdk` includes a compiler, clang, the standard library and system root for compiling C and C++ to WebAssembly using WASI.

Given we have installed the `wasi-sdk` we can compile the same C source code from above, and we will get a WebAssembly binary that we can run with wasmtime.

When compiling, you should add the `--sysroot` parameter, pointing to the `wasi-sysroot` folder from your downloaded `wasi-sdk`.

```bash
path/to/wasi-sdk/bin/clang --sysroot=path/to/wasi-sdk/share/wasi-sysroot listfiles.c -o listfiles.wasm
```

Since the program will access your local directory we need to provide the `--dir` parameter when running:

```bash
wasmtime --dir .::. listfiles.wasm 
```

# Beyond the capabilities of WASI preview 1

A very simple example, a very typical use case that goes beyond the capabilities of WASI preview 1 is a socket server. And where the first version of WASI stopped, there have been several initiatives to provide the missing features.

Let us see the source code of a minimum socket server that replies with `hello` when connecting to it:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

#define PORT 15000

int main() {
    int server_fd, new_socket;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char *hello = "hello";

    // Creating socket file descriptor
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }

    // Bind the socket to the port 15000
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address))<0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }

    // Listen for incoming connections
    if (listen(server_fd, 3) < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }

    // Accept an incoming connection
    if ((new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen))<0) {
        perror("accept");
        exit(EXIT_FAILURE);
    }

    // Send "hello" message to the client
    send(new_socket, hello, strlen(hello), 0);
    printf("Hello message sent\n");

    // Close the socket
    close(new_socket);

    return 0;
}
```

If we compile it, not to WebAssembly, but as a native application:

```bash
clang socketserver.c -o socketserver
```

Then we can run it by typing `./socketserver`, open a new terminal, and connect to it using a TCP client. Here is an example with "netcat":

`nc localhost 15000`

This prints `hello`. We have connected to our socket server, and got a reply.

If we compile it with Emscripten, we will get references to the Javascript API, and it will not run with a non-javascript WebAssembly runtime. If we try compiling it with the wasi-sdk, it will fail to compile since some of the functions are not known to WASI.

# WASIX

One of the initiatives to bridge the gaps of the missing features in WASI is WASIX by wasmer.io. WASIX adds several operating system features, and makes it possible for us to compile the socket server example above and run it in the Wasmer WebAssembly runtime.

To use WASIX, we can still use the compiler from wasi-sdk, but we'll point to the sysroot from WASIX instead. To obtain a WASIX sysroot, you should go to the github repository for `wasix-libc` which you can find here: https://github.com/wasix-org/wasix-libc. Go into the latest build, download the `wasix-sysroot` artifact, and extract it into a folder on your machine.

Then you can compile `socketserver.c`, but now using the path to `wasix-sysroot` as the `--sysroot` parameter value.

```bash
/path/to/wasi-sdk/bin/clang --sysroot=/path/to/wasix-sysroot socketserver.c -o socketserver.wasm
```

This will only work with `wasmer`, but you can now type the following to run the socket server:

```bash
wasmer run --net socketserver.wasm
```

The `--net` flag enables the networking features we need for running the socket server.

When the server is running we can also connect to it with the same command with used when compiling the socket server natively:

`nc localhost 15000`

And the `hello` message will be printed to the console.

WASIX is a straight forward way to get access to many of the operating system features missing in WASI preview 1. It is developed by the Wasmer team, with hopes of more runtimes to join. On the other hand, there is the upcoming second preview of WASI in connection with the WebAssembly Component Model.

# WASI Preview 2 and the WebAssembly Component Model

WASI Preview 2 is in development as part of the ongoing standardization initiatives led by the W3C WebAssembly Community Group and the Bytecode Alliance. It is different from other projects to extend WASI, since it introduce a new WebAssembly binary format which is called the WebAssembly Component Model. The component model introduces an Interface Definition Language called WIT ( WebAssembly Interface Types ), making it possible to connect WebAssembly component modules. Component modules may be written in different languages, but still interact through interfaces defined using the WIT language.  

The Wasm component model is in an early stage. There are constant improvements, and also changes. Tools and documentation may be hard to find, but still the evolution has come so far that it is possible to use it and see the possibilities. Access to the world outside the Wasm sandbox through components is an approach that aligns with security principles of least privilege (only getting access to what you need). Your application will only pull in the needed components. Separation of Concerns is another software architecture principle that is supported through the component approach. The component model lays out a foundation aiming for both security and maintainability.

A WebAssembly Component can be built from a "core module". A "core WebAssembly module" is the kind of WebAssembly modules we have been working with until now in this book. A Wasm core module binary starts with the 4 first bytes, that we call the "magic number": `\0asm`, and it's the same for a Wasm component module. From the next bytes it is different. There is a higher version number, and a new set of definitions.

If we translate a Wasm component module to WebAssembly text format, we can immediately see some of the new definitions that we don't have in core Wasm.

Here is a simple WebAssembly component that provides a function to multiply two numbers

```
(component
  (core module (;0;)
    (type (;0;) (func (param i32 i32) (result i32)))
    (func (;0;) (type 0) (param i32 i32) (result i32)
      local.get 0
      local.get 1
      i32.mul
    )
    (export "example:multiply/multiplier#mul" (func 0))
    (@producers
      (processed-by "wit-component" "0.200.0")
    )
  )
  (core instance (;0;) (instantiate 0))
  (type (;0;) (func (param "a" s32) (param "b" s32) (result s32)))
  (alias core export 0 "example:multiply/multiplier#mul" (core func (;0;)))
  (func (;0;) (type 0) (canon lift (core func 0)))
  (component (;0;)
    (type (;0;) (func (param "a" s32) (param "b" s32) (result s32)))
    (import "import-func-mul" (func (;0;) (type 0)))
    (type (;1;) (func (param "a" s32) (param "b" s32) (result s32)))
    (export (;1;) "mul" (func 0) (func (type 1)))
  )
  (instance (;0;) (instantiate 0
      (with "import-func-mul" (func 0))
    )
  )
  (export (;1;) "example:multiply/multiplier" (instance 0))
  (@producers
    (processed-by "wit-component" "0.200.0")
  )
)                                  
```

What we can see from this is that it has a core module embedded. It is actually generated using `wasm-tools`, which is able to create a component from a core module by embedding it. We can see the original core module just after the `component` definition in the top.

Here is the original core module, that we will call `mul.wat`

```
(module
  (func $mul (param $a i32) (param $b i32) (result i32)
    local.get $a
    local.get $b
    i32.mul)
  (export "example:multiply/multiplier#mul" (func $mul))
)
```

Take note of the naming of the exported function `example:multiply/multiplier#mul`. This is formatted to conform with the WIT file that we need to create for the interface definition.

We can create a file that we call `mul.wit`.

```
package example:multiply;

interface multiplier {
  mul: func(a: s32, b: s32) -> s32;
}

world multiplierexports {
    export multiplier;
}
```

This describes the interface that we would like to make available for other components. Now that we have both a core module and a wit file, we can create the component.

First we need to translate the core module to WebAssembly:

```bash
wat2wasm mul.wat -o mul.core.wasm
```

Then we can embed the core module. To do this you need to install `wasm-tools`, which you can find at https://github.com/bytecodealliance/wasm-tools. When installed, we can run it with the embed command.

```bash
wasm-tools component embed --world multiplierexports . mul.core.wasm -o mul.embed.wasm
```

The next step is to create the component wasm, with the following command:

```bash
wasm-tools component new mul.embed.wasm -o mul.wasm
```

We can not use `wasm2wat` to see the WebAssembly Text Format of the final component WebAssembly binary, but we can use `wasm-tools` with the `print` command:

```bash
wasm-tools print mul.wasm 
```

This will print the WebAssembly Text Format of the component, which we saw in the beginning of this section.

The next step now, is to use this component. With WASI preview 2 we can create CLI applicatons, but an interesting feature is the `wasi:http` package. This package contains an `incoming-handler` for HTTP requests, that let us write HTTP handler components. It let us write request handling functions, just like in "Serverless" frameworks. In a "Serverless" infrastructure, we are just writing the handling code of an API call, we don't write the server that listens for requests. `wasmtime` has a command called `serve`, that works with components that implements `wasi:http/incoming-handler`. All HTTP requests are then routed to the component.

We wrote our first component in pure WebAssembly Text Format. For the HTTP handler component it's easier to write it in Rust. Let us first start by creating a simple Rust WASI project.

Here is the file and folder structure of our `http-handler` rust project.

```
http-handler/
├── src/
│   └── lib.rs
├── Cargo.toml
├── mul.wasm
├── mul.wit
```

Our `Cargo.toml` file references the `wasi` and `wit-bindgen` crates, and looks like this:

```
[package]
name = "httphandler"
version = "0.1.0"
edition = "2021"

[dependencies]
bitflags = "2.4.2"
wasi = { git ="https://github.com/bytecodealliance/wasi.git", features = ["macros"] }
wit-bindgen = "0.20.0"
wit-bindgen-rt = "0.20.0"

[lib]
crate-type = ["cdylib"]

[profile.release]
lto = true
opt-level = 'z'
debug = false
strip = 'symbols'
```

Now let's look at `src/lib.rs`:

```rust
mod multiplierimports;
use multiplierimports::example::multiply::multiplier::mul;

use wasi::http::types::{
    Fields, IncomingRequest, OutgoingBody, OutgoingResponse, ResponseOutparam,
};

wasi::http::incoming_handler::export!(Example);

struct Example;

impl exports::wasi::http::incoming_handler::Guest for Example {
    fn handle(_request: IncomingRequest, response_out: ResponseOutparam) {
        let resp = OutgoingResponse::new(Fields::new());
        let body = resp.body().unwrap();

        ResponseOutparam::set(response_out, Ok(resp));

        let out = body.write().unwrap();

        let product = mul(4, 8);
        let outstring = format!("Hello {}", product);
        out.blocking_write_and_flush(outstring.as_bytes()).unwrap();
        drop(out);

        OutgoingBody::finish(body, None).unwrap();
    }
}
```

We can see that it declares a `handle` function for an incoming http request. Such a function with the `request` and `response_out` as parameters, is a very typical http handler function interface that you can see in many "serverless" and http function frameworks. It allows us to inspect the parameters and headers of the request, and control the response output. In our implementation you can see that we are calling the `mul` function, and sending the product as part of the response output string.

The `mul` function comes from the `multiplierimports` module, which we don't have yet. We only have `mul.wasm` from above, and `mul.wit`, the WebAssembly Interface Type definition file. We can use `wit-bindgen` to create the `src/multiplierimports.rs` file.

Before we can use `wit-bindgen` we need to add another "world" to our `mul.wit` file. We already have a world called `multiplierexports`, but using `wit-bindgen` on this would only generate export definitions in our Rust sources. In our current use case, we want to *import* the `mul` function, and so we need to declare a world that imports that function.

Let us add the following lines to `mul.wit`:

```
world multiplierimports {
  import multiplier;
}
```

Now we have a new world called `multiplierimports`, and we should reference this when running `wit-bindgen`. 

To be able to run `wit-bindgen` we need to install it first. It can be installed easily using `cargo`:

```bash
cargo install wit-bindgen-cli
```

Then we can run it to create our Rust bindings:

```bash
wit-bindgen rust --out-dir src --world multiplierimports mul.wit
```

After running this, we now have the `src/multiplierimports.rs` file. And we are ready to build:

```bash
cargo build --target=wasm32-wasi --release
```

Now we have a core WebAssembly module `target/wasm32-wasi/release/httphandler.wasm`. We are not able to run it using `wasmtime serve` yet. We have to convert it to a component.

We can convert it to a component using `wasm-tools`, just like we did with the `mul.wasm` component above. Since the generated core module use the `wasi` crate, it will also import some functions from WASI preview 1. `wasm-tools` let us handle this using the `--adapt` parameter, which we need to provide with a proxy module that we can download from the `wasmtime` releases page at https://github.com/bytecodealliance/wasmtime/releases/tag/v18.0.2.

Download the `wasi_snapshot_preview1.proxy.wasm` file, and provide the path of it to the `--adapt` parameter of `wasm-tools`.

```bash
wasm-tools component new target/wasm32-wasi/release/httphandler.wasm --adapt wasi_snapshot_preview1.proxy.wasm -o httphandler.wasm
```

There is still one thing preventing us from running it using `wasmtime serve`. The `httphandler.wasm` component module does not contain the contents of of `mul.wasm`, and so it will not be able to find the `mul` function.

To fix this, we have to *compose* the two component files into one, which we can do using `wasm-tools`.

```bash
wasm-tools compose -o httphandler_composed.wasm httphandler.wasm -d mul.wasm
```

Now we have the `httphandler_composed.wasm` file that we can run. When running the last command, you will see several warnings displayed about instances that will be imported. All of these interfaces starting with `wasi:` in the names, will be provided by `wasmtime` when running.

To run the component, type the following command:

```bash
wasmtime serve httphandler_composed.wasm
```

If you navigate to http://localhost:8080 in your browser, you should see the text `Hello 32` which is the result of our http handler printing the string `Hello` and the result of calling the `mul` component function with the parameters `4` and `8`.

## Combining components written in different languages

With the http handler above we combined two different WebAssembly binaries, one written in Rust, and the other written in WebAssembly Text Format. The component model approach let us combine WebAssembly modules compiled from different languages. Any language capable of compiling to WebAssembly can be converted to a WebAssembly component.

Let us create a simple tone generator in AssemblyScript, that we will turn into a component for use in the HTTP handler.

```typescript
const SAMPLERATE: f32 = 44100;
let step: f32;
let position: f32 = 0;

export function setnote(note: f32): void {
    const frequency = (440.0 as f32) * Mathf.pow(2, (-69 + note) / 12);
    step = frequency / SAMPLERATE;
}

export function nextsample(): f32 {
    position += step;
    return Mathf.sin(position * Mathf.PI * 2.0);
}
```

We will compile this to a WAT file since we need to modify the export names to match the WIT below.

```bash
asc --runtime=stub -Oz --use abort= tonegenerator.ts -t tonegenerator.core.wat
```

This will give us the WAT file named `tonegenerator.core.wat`. The exported functions are named `setnote` and `nextsample`, but we need it to match the `tonegeneratorexports` world of the following WIT file:

```
package example:tonegenerator;

interface tonegeneratorsynth {
  setnote: func(notenumber: f32);
  nextsample: func() -> f32;
}

world tonegeneratorexports {
    export tonegeneratorsynth;
}

world tonegeneratorimports {
    import tonegeneratorsynth;
}
```

By running the following commands we can immediately see how the exports should be named:

```bash
wasm-tools component embed tonegenerator.wit --world tonegeneratorexports tonegenerator.core.wat -o tonegenerator.embed.wasm
wasm-tools component new tonegenerator.embed.wasm -o tonegenerator.wasm
```

The last command gives an error message with the following line:

```
module does not export required function `example:tonegenerator/tonegeneratorsynth#setnote`
```

To fix this we will edit the following lines of `tonegenerator.core.wat`:

```
(export "setnote" (func $tonegenerator/setnote))
(export "nextsample" (func $tonegenerator/nextsample))
```

We will change them to this:

```
(export "example:tonegenerator/tonegeneratorsynth#setnote" (func $tonegenerator/setnote))
(export "example:tonegenerator/tonegeneratorsynth#nextsample" (func $tonegenerator/nextsample))
```

Now we can run the two `wasm-tools` commands again, and we will get the component wasm file `tonegenerator.wasm`.

Let us use it in our http handler Rust code. First we will have to create the bindings, and we can use `wit-bindgen` for this. In this case we will create it from the `tonegeneratorimports` world.

```bash
wit-bindgen rust --world tonegeneratorimports tonegenerator.wit
```

We can copy the generated file, `tonegeneratorimports.rs`, into the `src` folder of our http-handler Rust project, and we will adjust our Rust http handler code to use it.

Here is our updated `src/lib.rs`:

```rust
mod tonegeneratorimports;
mod multiplierimports;

use multiplierimports::example::multiply::multiplier::mul;
use tonegeneratorimports::example::tonegenerator::tonegeneratorsynth::{nextsample,setnote};

use wasi::http::types::{
    Fields, IncomingRequest, OutgoingBody, OutgoingResponse, ResponseOutparam,
};

wasi::http::incoming_handler::export!(Example);

struct Example;

impl exports::wasi::http::incoming_handler::Guest for Example {
    fn handle(_request: IncomingRequest, response_out: ResponseOutparam) {
        if _request.path_with_query().unwrap() == "/music" {
            let headers = Fields::new();
            headers.set(&"content-type".to_string(), &["audio/wav".as_bytes().to_vec()]).unwrap();
            let resp = OutgoingResponse::new(headers);
            let body = resp.body().unwrap();

            ResponseOutparam::set(response_out, Ok(resp));

            let out = body.write().unwrap();

            const SAMPLERATE: usize = 44100;
            const SECONDS: usize = 5;
            const TRACK_LENGTH: usize = SAMPLERATE * SECONDS;
            let notenumbers: [f32; SECONDS] = [60.0, 62.0, 64.0, 65.0, 67.0];

            // Preparing WAV header
            let header = create_wav_header(SAMPLERATE as u32, 1, 32, TRACK_LENGTH as u32);
            out.blocking_write_and_flush(&header).unwrap(); // Write the WAV header to the output

            for n in 0..TRACK_LENGTH {
                if n % SAMPLERATE == 0 {
                    setnote(notenumbers[n / SAMPLERATE])
                }
                let sample = nextsample();
                // Convert f32 sample to bytes in little-endian format
                let sample_bytes = sample.to_le_bytes();
                out.blocking_write_and_flush(&sample_bytes).unwrap();
            }

            drop(out);

            OutgoingBody::finish(body, None).unwrap();
        } else { 
            let resp = OutgoingResponse::new(Fields::new());
            let body = resp.body().unwrap();

            ResponseOutparam::set(response_out, Ok(resp));

            let out = body.write().unwrap();
       
            let product = mul(4, 8);
            let outstring = format!("Hello {}", product);
            out.blocking_write_and_flush(outstring.as_bytes()).unwrap();
            drop(out);

            OutgoingBody::finish(body, None).unwrap();
        }
    }
}


fn create_wav_header(sample_rate: u32, num_channels: u16, bits_per_sample: u16, num_samples: u32) -> Vec<u8> {
    let block_align = num_channels * bits_per_sample / 8;
    let byte_rate = sample_rate * u32::from(block_align);
    let data_chunk_size = num_samples * u32::from(block_align);
    let file_size = 36 + data_chunk_size; // 36 bytes for header + data chunk size

    let mut header = Vec::new();

    // RIFF chunk descriptor
    header.extend_from_slice(b"RIFF");
    header.extend_from_slice(&(file_size + 8).to_le_bytes()); // File size + 8 for RIFF and size fields
    header.extend_from_slice(b"WAVE");

    // fmt subchunk
    header.extend_from_slice(b"fmt ");
    header.extend_from_slice(&16u32.to_le_bytes()); // PCM chunk size
    header.extend_from_slice(&3u16.to_le_bytes());
    header.extend_from_slice(&num_channels.to_le_bytes());
    header.extend_from_slice(&sample_rate.to_le_bytes());
    header.extend_from_slice(&byte_rate.to_le_bytes());
    header.extend_from_slice(&block_align.to_le_bytes());
    header.extend_from_slice(&bits_per_sample.to_le_bytes());

    // data subchunk
    header.extend_from_slice(b"data");
    header.extend_from_slice(&data_chunk_size.to_le_bytes());

    header
}
```

Let us break down the changes here. We are now using the `nextsample` and `setnote` functions from our tone generator module, as we can see from this line:

```rust
use tonegeneratorimports::example::tonegenerator::tonegeneratorsynth::{nextsample,setnote};
```

Further down in our `handle` function we are checking the incoming request path if it matches `/music`:

```rust
if _request.path_with_query().unwrap() == "/music" {
```

Inside this section we are setting the content type header to `audio/wav`, and we have defined a little sequence of note numbers that we pass into our tone generator every second. One second is every 44100th sample, 44100 is the sample rate. We write each sample that we get from the tone generator to the handler response output. Note that there is also the function `create_wav_header` which we use to create and write a WAV audio file header to the response output before sending the actual audio data. 

Again we can compile, and build the component module with the following commands:

```bash
cargo build --target=wasm32-wasi --release
wasm-tools component new target/wasm32-wasi/release/httphandler.wasm --adapt wasi_snapshot_preview1.proxy.wasm -o httphandler.wasm
```

Our `wasm-tools compose` is now extended to include `tonegenerator.wasm`:

```bash
wasm-tools compose -o httphandler_composed.wasm httphandler.wasm -d mul.wasm -d tonegenerator.wasm
```

And we can finally serve it with `wasmtime`:

```bash
wasmtime serve httphandler_composed.wasm
```

Navigating our browser to http://localhost:8080/ still returns the output of the `mul` module, but if we navigate to http://localhost:8080/music we will get the audio file.

# WasmEdge, embedding WebAssembly into native applications

We have seen the serverless approach using `wasmtime serve` and the WebAssembly Component Model. Another runtime that oriented around serverless is WasmEdge, a Cloud Native Computing Foundation (CNCF) sandbox project. CNCF is also a strong driver of industry standards, with Kubernetes being one of the most important projects associated with it. WasmEdge is one of the runtimes we're going to look at in the last chapter about WebAssembly on Kubernetes. While we can use WasmEdge for serverless on several cloud platforms, and for container based workloads on Kubernetes, it is reassuring to know that it is also committed to supporting and implementing the Component Model proposal that we have demonstrated in the previous section. We can expect WasmEdge to support for the Component Model in the future, but there are already also several examples of non-standard extensions for WASI preview 1, just as we saw with WASIX.

Another interesting capability of WebAssembly runtimes is embedding WebAssembly into native apps. WasmEdge is no exception, and can easily run WebAssembly modules inside apps written in several languages.

Let us revisit the music instrument plugin from chapter 9, where we converted WebAssembly to C. Instead of converting to C, we can embed WasmEdge directly into the C++ code, and load the unmodified WebAssembly binary directly.

Compared to our previous `wasmedgesynth.cpp`, there will be some changes. Let us look at the first part where we initialize the WasmEdge virtual machine.

```c++
#include <JuceHeader.h>
#include <wasmedge/wasmedge.h>

class WasmEdgeSynth final : public AudioProcessor
{
public:
    WasmEdgeSynth()
        : AudioProcessor(BusesProperties().withOutput("Output", AudioChannelSet::stereo()))
    {
        WasmEdge_ConfigureContext *ConfCxt = WasmEdge_ConfigureCreate();

        WasmEdge_CompilerContext *CompilerCxt = WasmEdge_CompilerCreate(ConfCxt);
        WasmEdge_CompilerCompile(CompilerCxt, "/path/to/song.wasm", "/path/to/song.wasm.so");

        WasmEdge_CompilerDelete(CompilerCxt);
        WasmEdge_ConfigureDelete(ConfCxt);

        vm_cxt = WasmEdge_VMCreate(NULL, NULL);
        WasmEdge_Result result = WasmEdge_VMLoadWasmFromFile(vm_cxt, "/path/to/song.wasm.so");

        printf("Loaded Wasm file, result: %d\n", result.Code);
    }
```

We can see that a WasmEdge configuration context is created to set up the compiler. The compiler is used to create a dynamic library ( `song.wasm.so` ) from the `song.wasm` file, which we are loading into the WasmEdge Virtual Machine.

There is also more code added to the `prepareToPlay` method. We set the sample rate as previously, by providing the `environment` import, but this time using the WasmEdge interfaces for creating a context for this import. Just like with any other WebAssembly runtime, including the one we have with Javascript in the browser and NodeJS, we have to instantiate the Wasm module. Also we prepare pointers to the function name for filling the sample buffer, and the memory address for the buffer. With the static library of the WebAssembly instance converted to C, we had symbols for these, but now we have to obtain pointers through the interfaces provided by WasmEdge.


```cpp
    void prepareToPlay(double newSampleRate, int) override
    {
        synth.setCurrentPlaybackSampleRate(newSampleRate);
        printf("Samplerate is %f\n", newSampleRate);

        if (environmentModuleInstanceContext != NULL) {
            WasmEdge_ModuleInstanceDelete(environmentModuleInstanceContext);
        }
        environmentModuleInstanceContext = WasmEdge_ModuleInstanceCreate(WasmEdge_StringCreateByCString("environment"));
        WasmEdge_VMRegisterModuleFromImport(vm_cxt, environmentModuleInstanceContext);
       
        WasmEdge_GlobalTypeContext *SAMPLERATE_type = WasmEdge_GlobalTypeCreate(WasmEdge_ValType_F32, WasmEdge_Mutability_Const);
        WasmEdge_GlobalInstanceContext *SAMPLERATE_global = WasmEdge_GlobalInstanceCreate(SAMPLERATE_type, WasmEdge_ValueGenF32(newSampleRate));
        WasmEdge_ModuleInstanceAddGlobal(environmentModuleInstanceContext, WasmEdge_StringCreateByCString("SAMPLERATE"), SAMPLERATE_global);

        WasmEdge_VMValidate(vm_cxt);
        printf("Wasm module validatedf\n");
        WasmEdge_VMInstantiate(vm_cxt);

        printf("Wasm module instantiated\n");

        const WasmEdge_ModuleInstanceContext *moduleCtx = WasmEdge_VMGetActiveModule(vm_cxt);
        WasmEdge_GlobalInstanceContext *globCtx = WasmEdge_ModuleInstanceFindGlobal(moduleCtx, WasmEdge_StringCreateByCString("samplebuffer"));
        WasmEdge_MemoryInstanceContext *memCtx = WasmEdge_ModuleInstanceFindMemory(moduleCtx, WasmEdge_StringCreateByCString("memory"));

        fillSampleBufferFuncNameString = WasmEdge_StringCreateByCString("fillSampleBufferWithNumSamples");
        WasmEdge_Value globValue = WasmEdge_GlobalInstanceGetValue(globCtx);
        uint32_t sampleBufferAddrValue = WasmEdge_ValueGetI32(globValue);

        const uint8_t *renderbytebuf = WasmEdge_MemoryInstanceGetPointer(memCtx, sampleBufferAddrValue, 128 * 2 * 4);
        renderbuf = (float32_t *)renderbytebuf;
        printf("Wasm module exports stored\n");

        printf("Prepare completed\n");
    }
```

The last part that we have changed is the `processBlock` function, but it's only that we have to call the WebAssembly functions through WasmEdge, instead of calling a static library directly. We call the `shortmessage` and `fillSampleBuffer` functions on the WebAssembly module through the `WasmEdge_VMExecute` method, and we also prepare the input variables using `WasmEdge_ValueGenI32` for the integer values. 

```cpp
    void processBlock(AudioBuffer<float> &buffer, MidiBuffer &midiMessages) override
    {
        for (const auto metadata : midiMessages)
        {
            MidiMessage message = metadata.getMessage();
            const uint8 *rawmessage = message.getRawData();

            WasmEdge_Value args[3];
            args[0] = WasmEdge_ValueGenI32((uint8_t)rawmessage[0]); // Replace param1, param2, param3 with actual values
            args[1] = WasmEdge_ValueGenI32((uint8_t)rawmessage[1]);
            args[2] = WasmEdge_ValueGenI32((uint8_t)rawmessage[2]);
            WasmEdge_VMExecute(vm_cxt, WasmEdge_StringCreateByCString("shortmessage"), args, 3, NULL, 0); // Adjust return count as necessary

            printf("sent midi to wasm synth: %d, %d, %d\n", rawmessage[0], rawmessage[1], rawmessage[2]);
        }

        int numSamples = buffer.getNumSamples();
        auto *left = buffer.getWritePointer(0);
        auto *right = buffer.getWritePointer(1);

        for (int sampleNo = 0; sampleNo < numSamples; sampleNo += 128)
        {
            int numSamplesToRender = std::min(numSamples - sampleNo, 128);

            WasmEdge_Value args[1] = {WasmEdge_ValueGenI32((uint32_t)numSamplesToRender)};
            WasmEdge_Result result = WasmEdge_VMExecute(vm_cxt, fillSampleBufferFuncNameString, args, 1, NULL, 0);

            for (int ndx = 0; ndx < numSamplesToRender; ndx++)
            {
                left[sampleNo + ndx] = renderbuf[ndx] * 0.3;
                right[sampleNo + ndx] = renderbuf[ndx + 128] * 0.3;
            }
        }
    }
```

Refer to the attached git repository for the complete source code. Let us explain it a bit more thorough.

In this example we are setting up the WasmEdge runtime to load and execute functions from the WebAssembly binary. We are also using the AOT ( Ahead-Of-Time ) compiler, to compile the WebAssembly to machine code. This is important because of real time calculation of audio data, and skipping this will cause the synth to not be able to produce proper sound. If not using AOT, the synth will not complete the `processBlock` method in time.

Note that this example does not have error handling, and it does not clean up resources properly. 

Let us break down the code. The constructor of `WasmeEdgeSynth` contains the AOT compilation part.

As you can see it creates the compiler, and calls the `WasmEdge_CompilerCompile` command. We are providing the path to the `song.wasm` file, and creating a new file called `song.wasm.so` that will contain the WebAssembly compiled to native machine code. Remember to replace `/path/to/` with the path to `song.wasm` and `song.wasm.so` on your system.

Then we load `song.wasm.so` into the WasmEdge VM with the command `WasmEdge_VMLoadWasmFromFile`.

Since the sample rate might change whenever `prepareToPlay` is called, and the sample rate is an import to the WebAssembly module, we have to move the instantiation part into the `prepareToPlay` method. Before we instantiate the module, we set the value of the import object, just like we do when instatiating a WebAssembly module from Javascript.

After validating and instantiating the WebAssembly module, we can find the exported `samplebuffer` pointer and `memory` array. We call `WasmEdge_MemoryInstanceGetPointer` to get a pointer to the location in the WebAssembly instance memory where the audio data will be rendered. 

We use this pointer in last part of the `processBlock` method where copy data from `renderbuf` to the `left` and `right` audio output buffers. In the beginning of `processBlock`, we call the `shortmessage` method on the WebAssembly instance to pass MIDI messages about notes to be played. After that we call `fillSampleBuffer`, but using the string reference `fillSampleBufferFuncNameString` that we created in `prepareToPlay`. The call to `fillSampleBuffer` will render the audio data to `renderbuf`.

As you can see it is the same as what we demonstrated in chapter 9 using `wasm2c`. It is the same WebAssembly, but in this case we did not have to convert it to C first. Using a WebAssembly runtime like WasmEdge, our application can load and run the WebAssembly binary as it is.

Linking WasmEdge into our c++ application requires some changes to our CMakeLists.txt, and to distribute a package that is self contained, it's the easiest to build WasmEdge as a static library.

Before we can build WasmEdge, we need to install build tools. Go to the WasmEdge website and find the installation instructions for your platform: https://wasmedge.org/docs/category/supported-platforms

Below is one way of downloading and building WasmEdge as a static library, which is also described in the WasmEdge documentation which can be found at https://wasmedge.org/docs/embed/c/library

```bash
wget https://github.com/WasmEdge/WasmEdge/archive/refs/tags/0.13.5.tar.gz
tar -xvzf 0.13.5.tar.gz

cd WasmEdge-0.13.5
cmake -Bbuild -GNinja -DCMAKE_BUILD_TYPE=Release -DWASMEDGE_LINK_LLVM_STATIC=ON -DWASMEDGE_BUILD_SHARED_LIB=Off -DWASMEDGE_BUILD_STATIC_LIB=On -DWASMEDGE_LINK_TOOLS_STATIC=On -DWASMEDGE_BUILD_PLUGINS=Off
cmake --build build
cmake --install build
```

This will install WasmEdge version 0.13.5 into our system so that we can compile and link it without pointing to specific include or lib folders.

Our modified CMakeLists.txt looks like this:

```
cmake_minimum_required(VERSION 3.15)

project(WasmSynth VERSION 0.0.1)

add_subdirectory(JUCE-7.0.9)

juce_add_plugin(WasmEdgeSynth
    COMPANY_NAME "WebAssemblyMusic"
    IS_SYNTH TRUE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE WaMu
    PLUGIN_CODE Wedg
    FORMATS VST3 AU Standalone)

target_sources(WasmEdgeSynth
    PRIVATE
        wasmedgesynth.cpp)

target_compile_definitions(WasmEdgeSynth
    PRIVATE
        JUCE_VST3_CAN_REPLACE_VST2=0)

target_link_libraries(WasmEdgeSynth
    PRIVATE
        juce::juce_audio_utils
        ${CMAKE_CURRENT_SOURCE_DIR}/libwasmedge.a
        z
        ncurses
        pthread # For -pthread, commonly needed for threading support
        m # For -lm, math library
    PUBLIC
        juce::juce_audio_plugin_client
        juce::juce_dsp
)

if(UNIX AND NOT APPLE)
    target_link_libraries(WasmEdgeSynth
        PRIVATE
            rt # For -lrt, time-related functions, not needed on macOS.
            dl # For -ldl, dynamic loading of shared libraries
    )
endif()

juce_generate_juce_header(WasmEdgeSynth)
```

The difference here is that we no longer link our own `instrlib` which we had when using `wasm2c`, but instead we link `wasmedge`. We also link libraries for compression (zlib), terminal (ncurses), threading and math, and if we are not on Apple, we also link `rt` and `dl`. Note that in this example, we copy the static library file `libwasmedge.a` from our wasmedge build into the current directory of our sources. We can also reference the path to this file directly, as long as we reference `libwasmedge.a` and not `wasmedge`. Linking to `wasmedge` could cause signature problems on OSX, which is why we instead reference the static library file directly.

We can the build the project as we did in chapter 9, by creating a build directory and running `cmake`:

```bash
mkdir build
cd build
cmake ..
cmake --build .
```

Now you can open the JUCE audio plugin host, or any other DAW and load the newly created plugin that use WasmEdge to play instruments generated with WebAssembly Music

![JUCE audio plugin host with WasmEdge synth](wasmedgesynth.png)

# Conclusion

WASI provides a set of imports for WebAssembly modules that use operating system features. WebAssembly runtimes provides implementations for these imports that can give access to standard input/output, files and more. Where the first preview version of WASI has limitations, there are implementations like WASIX that to provides the missing interfaces for enabling more operating system capabilities such as hosting a socket server. In WASI preview 2 we see that we get more capabilities through standardized APIs, and there is also a new Wasm binary format and component model. The component model allows us to combine components written in different languages, and interaction between them is defined through the WIT Interface Definition Language. Finally we demonstrated the performance of WebAssembly through the WasmEdge WebAssembly runtime, with real time audio rendering. We demonstrated how it can be embedded into a native C++ application.

# Points to remember

- The first version of WASI provides implementations of operating system interfaces
- WebAssembly runtimes like Wasmtime, Wasmer and WasmEdge let us run Wasm modules from the command line that use WASI for interacting with input, output and files
- wasi-sdk provides a system root and a standard library for C, but we run into limitations like when for example creating a socket server
- WASIX does implement even more interfaces, extending WASI with missing features
- The future of WASI is the component model, where new interfaces are component packages and WebAssembly modules using them are components
- WebAssembly Components written in different languages can be combined and interact through interfaces defined in the WIT Interface Definition Language
- Using AOT compilation with WasmEdge we can embed WebAssembly into a native application that needs fast, real time audio data calculation.
- Embedding a WebAssembly runtime lets us use WebAssembly in any application, without having to convert it into the language of the target application.

# Exercises

- Write a tone generator component in C or anotherother language and replace it using `wasm-tools compose`
- Use WebAssembly Music to create different instrument WebAssembly binaries and load it into the JUCE plugin
