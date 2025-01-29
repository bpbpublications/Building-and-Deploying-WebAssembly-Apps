# Chapter 6: Porting a Large C Library to WebAssembly: Wasm-Git

# Introduction

In the previous chapter we learned that we can use Emscripten for compiling C/C++ codebases to WebAssembly, and in this chapter we will look into a large and known C library: libgit2. There is already a port of this to WebAssembly in the project "wasm-git" which can be found at https://github.com/petersalomonsen/wasm-git. When using this library in the browser or from nodejs, we are interacting with files and network, and we have all the functionality of a local Git client. Just like Git keeps a full copy of the repository locally, including the full history, wasm-git keeps the full repository contents in the browser storage. This makes it possible to have local data storage for Web apps, even available offline, with the possibility to sync with a remote server, using Git push or pull. The port of Wasm-git to WebAssembly demonstrates several features of Emscripten as well as capabilities of WebAssembly.

# Structure

- Offline capable web apps with local storage and synchronization
    - Initializing network and loading the WebAssembly module
    - Setting up the filesystem
    - Authorization with the git server
    - Using the filesystem as a data storage for app functionality
    - Sending data to the git server
- Building wasm-git
    - Network transport
    - Async network transport
- Building a command line interface to connect with the Libgit2 API
- Making the web app accessible when disconnected from the internet

# Objectives

In this chapter you will learn how to create a minimal web app that stores data in the browsers IndexedDB database through the Emscripten file system. You will get to know the library wasm-git, and by that experience a real use case of porting a large C library like Libgit2 to WebAssembly. One important thing to notice from this chapter is how to handle C code that interacts synchronuously with the network in the asyncrhonuous Javascript world. It's also important to take note of the complexity of interaction between a C library and Javascript, and that we in this case need to solve this by using a Command Line Interface approach and the file system.

# Offline capable web apps with local storage and synchronization

Libgit2 is a library written in C, for embedding git client functionality into applications. It is used by Git GUI clients and Git hosting providers like GitHub, GitLab and Azure Devops. A fundamental feature of Git is that respositories are cloned to your local device. A full copy of the contents and history is stored locally, and you don't need to be connected to the internet to work with it. You can even commit new revisions, or roll back to previous versions without being connected to a server, it is all available offline. When connecting to the network you can push your changes, or pull changes from the remote, and you can even synchronize with multiple remote servers. With technologies in modern browsers such as service workers, IndexedDB and Progressive Web Apps, we can deliver web applications that are available without being connected to the internet. Using the features of git to commit data revisions and synchronize remotes, we can synchronize changes when a connection is available. This brings a new dimension to providing web apps that are always available, since we don't depend on the server to be online. Wasm-git is built on this idea, leveraging Libgit2 in a WebAssembly binary and using IndexedDB as a local filesystem, which is a feature of Emscripten.

Before we look into the details, let us provide a simple example of a web app using wasm-git that is available offline, and can synchronize data with a remote server. We will create our web application in a single HTML file, with the Javascript modules embedded in it. 

Let us break it up into parts, and we will look at the HTML part first.

```html
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
        #svgviewarea {
            width: 500px;
            max-width: 100%;
            height: 500px;
            border: black solid 1px;
        }
        #consolearea {
            width: 100%;
            height: 200px;
        }
    </style>
</head>
<body>
    <input type="text" id="user.email" placeholder="email" />
    <input type="text" id="user.name" placeholder="name" />
    <input type="text" id="commit.message" placeholder="message" />
    <button id="publishbutton">Publish</button>
    <input type="text" id="color_input" style="width: 50px;position: absolute; display: none; z-index: 1000;" />
    <div id="svgviewarea">

    </div>
    <textarea id="consolearea"></textarea>
</body>
```

What we have here is a simple HTML form with text fields for user email and name. These are required to be able to commit to a git repository. We also have a field for the commit message. The publish button will create the commit and push to the server. The Javascript for handling the button click is in the next part below. Then we have the svg area where we will display our drawing. The color input will move and appear when the user clicks inside the drawing area. Finally we have the textarea to display console output from the git commands.

In the next part we are preparing for loading the wasm-git library. Version 0.0.12 of wasm-git is not an ESM module (ECMAScript module), and so this first part with a `<script>` tag does not have the `type="module"` attribute. We are also loading the `nacl-fast` library which we will use for creating access tokens to be able to sync ( git push / pull ) with the server.

```html
<script src="https://cdn.jsdelivr.net/npm/tweetnacl@1.0.3/nacl-fast.min.js"></script>
<script>
    const consolearea = document.getElementById('consolearea');
    Module = {
        locateFile: function (s) {
            return 'https://cdn.jsdelivr.net/npm/wasm-git@0.0.12/' + s;
        },
        print: function(msg) {
            console.log(msg);
            consolearea.value += (msg+'\n');
        },
        printErr: function(msg) {
            console.error(msg);
            consolearea.value += (msg+'\n');
        }
    };
    XMLHttpRequest.prototype._open = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url, async, user, password) {
        this._open(method, url, async, user, password);
        this.setRequestHeader('Authorization', `Bearer ${globalThis.accesstoken}`);
    }
</script>
```

This first script part sets up the Emscripten `Module` object and patch `XMLHttpRequest`, which we will explain in more detail below where we break it down into even more.

In the last script part we load the wasm-git library, and we implement the rest of the Javascript as an ESM module ( ECMAScript module ) since this lets us for example use `await` without having to declare `async` functions.

```html
<script src="https://cdn.jsdelivr.net/npm/wasm-git@0.0.12/lg2_async.js"></script>
<script type="module">
    await new Promise(resolve => globalThis.Module.onRuntimeInitialized = () => resolve());
    const FS = Module.FS;

    FS.mkdir('/pixeldrawingworkdir');
    FS.mount(FS.filesystems.IDBFS, {}, '/pixeldrawingworkdir');
    await new Promise(resolve => FS.syncfs(true, () => resolve()));
    FS.chdir('/pixeldrawingworkdir');

    const privateKey = new Uint8Array([254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78, 4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246, 60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102, 49, 14, 108, 234, 201, 122, 62, 159]);
    const tokenMessage = btoa(JSON.stringify({ accountId: '3e393bf74cf63cf8e3851ea0fe6a92e56595f506947d7c66310e6ceac97a3e9f', iat: new Date().getTime() }));
    const signature = nacl.sign.detached(new TextEncoder().encode(tokenMessage), privateKey);
    globalThis.accesstoken = tokenMessage + '.' + btoa(String.fromCharCode(...signature));

    if (FS.readdir('.').indexOf('pixeldrawing') == -1) {
        await Module.callMain(['clone', 'https://wasm-git.petersalomonsen.com/pixeldrawing', 'pixeldrawing']);
        FS.chdir('pixeldrawing');
    } else {
        FS.chdir('pixeldrawing');
        await Module.callMain(['fetch', 'origin']);
        Module.callMain(['merge', 'origin/master']);
    }

    const writeToIndexedDB = async () => await new Promise(resolve => FS.syncfs(false, () => resolve()));
    await writeToIndexedDB();

    let colors_array;
    try {
        colors_array = JSON.parse(FS.readFile('drawing.json', { encoding: 'utf8' }));
    } catch (e) {
        console.log(e);
        colors_array = new Array(81).fill('#000');
    }
    const WIDTH = 9;
    const HEIGHT = 9;
    const svgstring = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${WIDTH} ${HEIGHT}">
                            ${colors_array.map((color, ndx) => `<rect x="${ndx % WIDTH}" y="${Math.floor(ndx / WIDTH)}" width="1" height="1" fill="${color}"/>`)}
                        </svg>`;
    const color_input = document.getElementById('color_input');
    const svgviewarea = document.getElementById('svgviewarea');
    svgviewarea.innerHTML = svgstring;
    Array.from(document.querySelectorAll('#svgviewarea svg rect'))
        .forEach((rect, ndx) => {
            rect.addEventListener('click', (e) => {
                color_input.style.top = `${e.clientY}px`;
                color_input.style.left = `${e.clientX}px`;
                color_input.value = rect.attributes.fill.value;
                color_input.style.display = 'block';
                color_input.onblur = async () => {
                    rect.attributes.fill.value = color_input.value;
                    colors_array[ndx] = color_input.value;
                    color_input.style.display = 'none';
                    FS.writeFile('drawing.json', JSON.stringify(colors_array, null, 1));
                    await writeToIndexedDB();
                }
            });
        }
        );
    const publishbutton = document.getElementById('publishbutton');
    publishbutton.addEventListener('click', async () => {
        publishbutton.disabled = true;
        Module.callMain(['config', 'user.name', document.getElementById('user.name').value]);
        Module.callMain(['config', 'user.email', document.getElementById('user.email').value]);
        Module.callMain(['add', 'drawing.json']);
        Module.callMain(['commit', '-m', document.getElementById('commit.message').value]);
        Module.print('pushing');
        await Module.callMain(['push']);
        await writeToIndexedDB();
        publishbutton.disabled = false;
    });
</script>
<script type="module">
    await navigator.serviceWorker.register('serviceworker.js', { scope: './' });
</script>
</html>
```

There are several things going on here, from setting up the file system, creating access tokens, drawing logic, and git interaction. All of this will be explained in more detail below, where we will look into each sections of this code.

The example is a simple pixel drawing application. A 9x9 matrix where the user can choose the color for each of the cells. The colors are stored in a JSON array, which is stored to a file in the git repository. Below is a screenshot of what it looks like.

![](./wasmgit.png)

## Initializing network and loading the WebAssembly module

Let us look deeper into the `script` parts of the HTML file above. The very first script we load is `tweetnacl`, which we will use to create a token for authenticating with the git server.

Before loading the git library `wasm-git`, we are initializing it with the following code:

```javascript
const consolearea = document.getElementById('consolearea');
Module = {
    locateFile: function (s) {
        return 'https://cdn.jsdelivr.net/npm/wasm-git@0.0.12/' + s;
    },
    print: function(msg) {
        console.log(msg);
        consolearea.value += (msg+'\n');
    },
    printErr: function(msg) {
        console.error(msg);
        consolearea.value += (msg+'\n');
    }
};
XMLHttpRequest.prototype._open = XMLHttpRequest.prototype.open;
XMLHttpRequest.prototype.open = function (method, url, async, user, password) {
    this._open(method, url, async, user, password);
    this.setRequestHeader('Authorization', `Bearer ${globalThis.accesstoken}`);
}
```

As you can see we are initializing an object called `Module`, and providing a function called `locateFile`. This function tells the Emscripten javascript runtime where to locate the WebAssembly binary and other files relative to the javascript file we are going to load after. Since we are loading the library from a Content Delivery Network ( CDN ), we also need to instruct Emscripten that other files also need to be loaded from that location.

We are also providing the functions `print` and `printErr`, which in addition to logging to the developer tools console, also outputs the messages to the textarea with the id `consolearea` that you can find in the HTML contents.

Then you can see the patching of `XMLHttpRequest`. The wasm-git library use `XMLHttpRequest` for synchronizing with the git server, and so we want to make sure that the authentication headers are also part of each request. We are patching the `open` method, where we set the `Authorization` request header of the `XMLHttpRequest` to contain an access token that we will create using the `tweetnacl` library as mentioned above.

The git server we are using here, is a custom one, which you can find at https://github.com/petersalomonsen/githttpserver. The reason for not using for example github, is because of CORS - Cross-origin resource sharing. CORS is a mechanism that the browsers apply for preventing a domain to access server resources of another domain. So in our case, when running our web application at from `localhost`, it will not be allowed to get data from `github.com`. As we can see from the source code the git server is located at `wasm-git.petersalomonsen.com`, and this server allows access from all domains. It does not have the CORS restriction. So we can use this server to host git repositories for web applications.

After the initializations of the `Module` object and `XMLHttpRequest`, we are ready to load the `wasm-git` library. From the URL https://cdn.jsdelivr.net/npm/wasm-git@0.0.12/lg2_async.js you can see that we are loading the `async` build. Just as C libraries are mostly built to do network calls synchronuously, this is also the case with `libgit2`. In the browser we can not do network requests synchronuously without running in a Web worker. If we want to run on the main thread, like in this example, we must use the `asyncify` feature of Emscripten to pause and resume the WebAssembly execution during the network requests. Wasm-git is built with and without `asyncify`, and in this case we are using the async build.

After loading the library, we can wait for it to be initialized:

`await new Promise(resolve => globalThis.Module.onRuntimeInitialized = () => resolve());`

This is simply waiting for the Emscripten `onRuntimeInitialized` event, which occurs when after the WebAssembly module has loaded.

## Setting up the filesystem

The next part is about setting up the filesystem:

```javascript
const FS = Module.FS;

FS.mkdir('/pixeldrawingworkdir');
FS.mount(FS.filesystems.IDBFS, {}, '/pixeldrawingworkdir');
await new Promise(resolve => FS.syncfs(true, () => resolve()));
FS.chdir('/pixeldrawingworkdir');
```

As we can see here, we are creating a directory and mounting it. Very much like mounting volumes in a Linux/Unix filesystem. Our volume in this case is named `/pixeldrawingworkdir` and we will mount it with the `IDBFS` filesystem, which is short for `IndexedDB File System`. `IndexedDB` is a nosql database built into browsers, storing content on the local device. By storing the cloned git repository in IndexedDB, it is possible to access the application data without connecting to a server.

You can inspect the contents of `IndexedDB` from within the browsers developer tools. As you can see from the screenshot below, each file of the locally cloned git repository has a record in `IndexedDB`. In the screenshot you can also see the internal files in the `.git` folder, which contains the full history of the repository. This way we have achieved to clone a whole repository into the web browser, just like when working with git in a regular file system.

![](./indexeddb.png)


## Authorization with the git server

The next part is about constructing a JSON Web Token that we will use for authorizing with the Git server:

```javascript
const privateKey = new Uint8Array([254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78, 4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246, 60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102, 49, 14, 108, 234, 201, 122, 62, 159]);

const tokenMessage = btoa(JSON.stringify({ accountId: '3e393bf74cf63cf8e3851ea0fe6a92e56595f506947d7c66310e6ceac97a3e9f', iat: new Date().getTime() }));
const signature = nacl.sign.detached(new TextEncoder().encode(tokenMessage), privateKey);
globalThis.accesstoken = tokenMessage + '.' + btoa(String.fromCharCode(...signature));
```

A JSON Web Token normally consists of a header, payload and signature. In this example we only have the payload and the signature, but otherwise it is quite the same concept. The token message, the payload, is a JSON object that contains the `accountId` and `iat` which is the creation date of the token. We are not using an external server for the authentication, but we are signing the token ourselves with the private key in the `Uint8Array`. We encode the payload as `base64` and sign it. The signature is then also encoded with base64 and we concatinate the payload and signature as string with a dot in between.

The `accountId` is in fact the public key that corresponds to the private key we used to sign. The server use this to verify the signature and will then look up the permissions for that account id. For this particular git server, the permissions are stored in a smart contract on the NEAR protocol blockchain. The account id, the public key, is actually a NEAR protocol blockchain address. This account does not have any funds, nor does it have any transactions recorded. Still we can use this private/public key pair to sign tokens to use for authorization, and a server can check the signature. Blockchain accounts are purely cryptographic key pairs, and does not need to be registered with a blockchain to be used. Later in this book we will look into how WebAssembly is used for creating smart contracts on NEAR protocol.

Now we have come to the part where we want to fetch the entire repository, or just updates from the server.

```javascript
 if (FS.readdir('.').indexOf('pixeldrawing') == -1) {
        await Module.callMain(['clone', 'https://wasm-git.petersalomonsen.com/pixeldrawing', 'pixeldrawing']);
        FS.chdir('pixeldrawing');
    } else {
        FS.chdir('pixeldrawing');
        await Module.callMain(['fetch', 'origin']);
        Module.callMain(['merge', 'origin/master']);
    }

    const writeToIndexedDB = async () => await new Promise(resolve => FS.syncfs(false, () => resolve()));
    await writeToIndexedDB();
```

In the first line of this snippet, you can see that we are checking if the folder `pixeldrawing` exists. If it does not, we are invoking the `clone` command. We are pointing to the URL of the repository, and providing the name of the directory we want to clone into: `pixeldrawing`. In case the directory already exists, because we have already cloned it earlier, then we just call `fetch` and `merge`, which is the same as `git pull`. Note that the arguments to the git commands are passed in an array, and they are quite the same as when using `git` from the command line. This will be explained further when we later in this chapter look into how the wasm-git WebAssembly binary is built.

The last line defines and calls the command `writeToIndexedDB`. We are using the `syncfs` method of the Emscripten file system, which synchronizes the memory contents into IndexedDB. It is not as IndexedDB is invoked for every file interaction, but the whole file system contents is replicated into memory. When calling the `syncfs` command, we are either reading or writing the entire filesystem to/from IndexedDB.

## Using the filesystem as a data storage for app functionality

Now we have got to the actual functionality for drawing and displaying. First we are reading the contents of the file `drawing.json` into an array. If the file does not exist, we will just fill the array with the black color `#000`.

```javascript
let colors_array;
try {
    colors_array = JSON.parse(FS.readFile('drawing.json', { encoding: 'utf8' }));
} catch (e) {
    colors_array = new Array(81).fill('#000');
}
```

Then from the array, we will construct an `svg`, that consists of 9x9 rectangles filled with the colors of the array.

```javascript
const WIDTH = 9;
const HEIGHT = 9;
const svgstring = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${WIDTH} ${HEIGHT}">
                        ${colors_array.map((color, ndx) => `<rect x="${ndx % WIDTH}" y="${Math.floor(ndx / WIDTH)}" width="1" height="1" fill="${color}"/>`)}
                    </svg>`;
```

In order to handle the action of drawing a pixel, we add a click handler on each of the rectangles.

```javascript
const color_input = document.getElementById('color_input');
const svgviewarea = document.getElementById('svgviewarea');
svgviewarea.innerHTML = svgstring;
Array.from(document.querySelectorAll('#svgviewarea svg rect'))
    .forEach((rect, ndx) => {
        colors_array.push(rect.attributes.fill.value);
        rect.addEventListener('click', (e) => {
            color_input.style.top = `${e.clientY}px`;
            color_input.style.left = `${e.clientX}px`;
            color_input.value = rect.attributes.fill.value;
            color_input.style.display = 'block';
            color_input.onblur = async () => {
                rect.attributes.fill.value = color_input.value;
                colors_array[ndx] = color_input.value;
                color_input.style.display = 'none';
                FS.writeFile('drawing.json', JSON.stringify(colors_array, null, 1));
                await writeToIndexedDB();
            }
        });
    }
);
```

Whenever the user clicks a rectangle, a color input text field appears, where the user can type the desired color. When the color input text field is exited, the `onblur` event, then the color array is updated, and also the file `drawing.json`. In order to not loose our changes if reloading the page we are also calling the `writeToIndexedDB` function so that the contents are written back to `IndexedDB`.

## Sending data to the git server

In the end there's a function for publishing, which calls git `add`, `commit` and `push`.

```javascript
const publishbutton = document.getElementById('publishbutton');
    publishbutton.addEventListener('click', async () => {
        publishbutton.disabled = true;
        Module.callMain(['config', 'user.name', document.getElementById('user.name').value]);
        Module.callMain(['config', 'user.email', document.getElementById('user.email').value]);
        Module.callMain(['add', 'drawing.json']);
        Module.callMain(['commit', '-m', document.getElementById('commit.message').value]);
        Module.print('pushing');
        await Module.callMain(['push']);
        await writeToIndexedDB();
        publishbutton.disabled = false;
    });
```

For each commit, Git requires that a name and email address is configured for the author.  It also requires a commit message. Again we can see that the invocations of `Module.callMain` contains arrays that are the same as the arguments we would pass to git on the terminal. In the end we also sync back to IndexedDB so that the local state is updated with the fact that we have pushed our changes to the server.

The example we have looked at here will in many cases handle that multiple users are making changes, provided that they always do it based on the latest commit. Just like git, libgit2 and wasm-git also has functionality for handling conflicts, but that is not part of this example.

# Building wasm-git

From the example above, you may have noticed that the entry point into the git library is the `callMain` function. `callMain` is a javascript method provided by the Emscripten JS runtime, that is able to invoke the `main` function of a C program and pass the parameters that we provide as an array when calling from Javascript.

If we look at part of the build script of wasm-git below, the configuration parameters passed to `cmake` are essential. We see that we have `-s INVOKE_RUN=0` which is preventing the `main` function to be executed without calling it explicitly. This way we can also call it several times without re-instantiating the WebAssembly instance. We also see that several features of libgit2 are switched off. For example we cannot use `ssh` and there is no need either to include `https` libraries since the browser has its own interfaces for that.

```bash
emcmake cmake -DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCMAKE_C_FLAGS="$EXTRA_CMAKE_C_FLAGS  --pre-js $(pwd)/pre.js $POST_JS -s \"EXTRA_EXPORTED_RUNTIME_METHODS=['FS','callMain']\" -lnodefs.js -lidbfs.js -s INVOKE_RUN=0 -s ALLOW_MEMORY_GROWTH=1 -s STACK_SIZE=131072" -DREGEX_BACKEND=regcomp -DSONAME=OFF -DUSE_HTTPS=OFF -DBUILD_SHARED_LIBS=OFF -DTHREADSAFE=OFF -DUSE_SSH=OFF -DBUILD_CLAR=OFF -DBUILD_EXAMPLES=ON ..
emmake make lg2
```

## Network transport

Replacing the networking is the hardest part when porting a library like libgit2 to run in the browser or in nodejs. The codebase of libgit2 is well structured, and allows us to replace it parts. Still we have to adapt our replacement to imitate a much lower level networking transport like the one provided by libgit2 when running natively. If we look at the `post.js` script, which we can find in the same directory as the build script ( the `emscriptenbuild` folder ), we see code that receives data chunks to be passed over the network and sends it when it's all ready. When using programming with native sockets, we send and receive chunks of data, but when using the Web APIs we pass all the request data at once. The C code expects native socket interfaces, with buffering and chunking data, so we need to provide a layer in between to facilitate that.

Another challenge is, as already mentioned, the asynchronuous nature of Javascript. Javascript is not supposed to block. There is no such thing as `sleep` or `wait`, which will pause and resume code execution later. Javascript is based on an "event loop", which means that code should never block. It should finish fast and let the next event be handled. When we use `await` in async methods, we let other events run. Javascript is also single threaded, so if there's a blocking loop, no other code will be able to execute.

In the browser there are two ways to get around this. The easiest way, and the way that does not block the main thread at all, is to use a Web Worker. The developer experience with a web worker is though a bit more complex, since it involves passing messages between the main thread and the worker. In the example above, where we are using the `Asyncify` build, and not a worker, we can easily take data from the UI components and save it directly to a file, and invoke git commands. If using a worker, we would have to use the `postMessage` command and `onmessage` event handler on the worker to communicate UI data updates to be saved in a file in the worker. In the worker we do not need the Asyncify build, and so the WebAssembly binary size is significantly smaller, since it does not need to include logic for pausing and resuming. The reason that we do not need this in a worker, is that there is actually support for synchronuous network calls from a worker.

Below is an extract of the javascript method invoked from within the C code of wasm-git. Notice the `xhr.open(method, url, false)`, where the third parameter instructs the network request to not be asynchronuous. The `xhr.send()` call further below, will then wait until the response has been received. 

```javascript
emscriptenhttpconnect: function(url, buffersize, method, headers) {
        if(!method) {
            method = 'GET';
        }

        const xhr = new XMLHttpRequest();
        xhr.open(method, url, false);
        xhr.responseType = 'arraybuffer';

        if (headers) {
            Object.keys(headers).forEach(header => xhr.setRequestHeader(header, headers[header]));
        }

        emscriptenhttpconnections[httpConnectionNo] = {
            xhr: xhr,
            resultbufferpointer: 0,
            buffersize: buffersize
        };
        
        if(method === 'GET') {
            xhr.send();
        }

        return httpConnectionNo++;
    },
```

The C code that calls this Javascript can be found in the `emscriptenhttp.c` file in the `transports` source folder of `libgit2patchedfiles`. This folder contains a few extra files added to libgit2 for handling the browser specific networking, and some extra additions to the `examples` folder which we use for exposing git functionality from the WebAssembly module. The additions and use of the `examples` will be described in the end of the chapter.

The `emscriptenhttp_stream_read` function below is part of the implementation of the network transport interface of libgit2. Calling into Javascript is done using the `EM_ASM_INT` macro provided by Emscripten, which allows us to insert the call to `Module.emscriptenhttpconnect` that we had in the JS snippet above.

```C
static int emscriptenhttp_stream_read(
	git_smart_subtransport_stream *stream,
	char *buffer,
	size_t buf_size,
	size_t *bytes_read)
{
    emscriptenhttp_stream *s = (emscriptenhttp_stream *)stream;

	if(s->connectionNo == -1) {
		s->connectionNo = EM_ASM_INT({
			const url = UTF8ToString($0);
			return Module.emscriptenhttpconnect(url, $1);
		}, s->service_url, DEFAULT_BUFSIZE);
	}

    *bytes_read = EM_ASM_INT({
		return Module.emscriptenhttpread($0, $1, $2);
    }, s->connectionNo, buffer, buf_size);

    return 0;
}
```

This `emscriptenhttpconnect` function returns an `int` which is used as a reference to the ongoing connection. From the javascript above we saw that this reference was stored into the global object `emscriptenhttpconnections`. Since the libgit2 transport calls `emscriptenhttp_stream_read` multiple times to retrieve multiple data chunks on the same connection, this refrence `s->connectionNo` will let the javascript part look up the ongoing connection and fill the passed buffer with another chunk of data.

From the `C` code we can see the call to `Module.emscriptenhttpread`, where we pass in the `connectionNo`, and buffer pointer and size. The Javascript implementation, which you can see below, then looks up the connection and fills the passed buffer with the part of the received result. Remember that XMLHttpRequest already contains the full data result, but it is because of the stream based implementation of the network transport in C that we have to provide a way for the C code to fetch data in smaller chunks.

```javascript
emscriptenhttpread: function(connectionNo, buffer, buffersize) { 
    const connection = emscriptenhttpconnections[connectionNo];
    if(connection.content) {
        connection.xhr.send(connection.content.buffer);
        connection.content = null;
    }
    let bytes_read = connection.xhr.response.byteLength - connection.resultbufferpointer;
    if (bytes_read > buffersize) {
        bytes_read = buffersize;
    }
    const responseChunk = new Uint8Array(connection.xhr.response, connection.resultbufferpointer, bytes_read);
    writeArrayToMemory(responseChunk, buffer);
    connection.resultbufferpointer += bytes_read;
    return bytes_read;
},
```

## Async network transport

In our small drawing applicatoin example, we did not use a web worker. We have developer friendly `async` / `await` calls to the git functionality that involves networking ( `clone`, `fetch`, `push` ).

From the build script `build.sh` we can see some `EXTRA_CMAKE_C_FLAGS` added for the Asyncify build

`-s ASYNCIFY -s 'ASYNCIFY_IMPORTS=[\"emscriptenhttp_do_get\", \"emscriptenhttp_do_read\", \"emscriptenhttp_do_post\"]'`

These flags instruct Emscripten to instrument the WebAssembly binary with the pause and resume features, and also which javascript functions that will pause WebAssembly execution when invoked.

Let us have a look at `emscriptenhttp_do_get`, which is declared inside the C code of the async transport implementation `emscriptenhttp-async.c`:

```c
EM_JS(int, emscriptenhttp_do_get, (const char* url, size_t buf_size), {
	return Asyncify.handleAsync(async () => {
		const urlString = UTF8ToString(url);
		return await Module.emscriptenhttpconnect(urlString, buf_size);
	});
});
```

Here we can see that it calls into an async javascript function, and using `await` on the result. the `Module.emscriptenhttpconnect` is implementation not very different from the synchronous worker example above, but a key difference is that it now sets the asynchronous parameter on `XMLHttpRequest.open` to `true`, and that the result of the network request is handled as an event.

```javascript
emscriptenhttpconnect: async function(url, buffersize, method, headers) {
    let result = new Promise((resolve, reject) => {
    if(!method) {
        method = 'GET';
    }

    const xhr = new XMLHttpRequest();
    xhr.open(method, url, true);
    xhr.responseType = 'arraybuffer';

    if (headers) {
        Object.keys(headers).forEach(header => xhr.setRequestHeader(header, headers[header]));
    }

    emscriptenhttpconnections[httpConnectionNo] = {
        xhr: xhr,
        resultbufferpointer: 0,
        buffersize: buffersize
    };
    
    if(method === 'GET') {
        xhr.onload = function () {
            resolve(httpConnectionNo++);
        };
        xhr.send();
    } else {
        resolve(httpConnectionNo++);
    }
    });
    return result;
},
```

We can see that this function now wraps everything in a Javascript promise, which the `handleAsync` above waits for to complete. We see that the `xhr.onload` event handler is responsible for resolving the promise with the connection reference. Just as above, we are able to implement and imitate the libgit2 network transport, even within the context of asynchronuous Javascript network requests. 

The pause and resume functionality of the Emscripten Asyncify feature involves some advanced handling of state. We will look more closer into this in a later chapter, and provide more isolated examples.

In Nodejs there is no network API offering the synchronous option of `XMLHttpRequest.open`, but there are "Worker threads". By performing the network request in a worker thread, and share memory with the main thread, it is possible to use `Atomics.notify` and `Atomics.wait` to signal and wait for async network requests to complete. This technique is used in the NodeJS implementation of wasm-git, and will be explained more thorough in the later chapter about asynchronuous WebAssembly.

# Building a command line interface to connect with the Libgit2 API

Libgit2 is primarily a library, it's not an application with a frontend or a command line interface. It is meant to be linked with other C/C++ applications. Even though we could the whole C API as WebAssembly exports, it would be quite complicated to consume from Javascript. We would have to write Javscript code to keep track of every `struct` in WebAssembly memory, maintain pointers to and allocate memory for these. If we would want to use the contents from Javascript we would have to write code to decode and transform it to Javascript objects.

Another option is to create a more Javascript friendly WebAssembly interface. We could use the features of Emscripten to call Javascript objects from C, and populate Javascript objects from the C code. Still this option would require us to write quite a bit of C for bridging the git functionality to Javascript.

Wasm-git has chosen another approach. Rather than exposing the Libgit2 API, or creating a wrapper for exposing it, it is using the examples from Libgit2. The `examples` folder in the Libgit2 source code contains sources for creating an executable that resembles much of the standard command line git application. There are examples for `clone`, `add`, `commit`, `push` and much more. In wasm-git there are even some additional example sources in the `libgit2patchedfiles` folder, that are created to complement with some additional essential `git` features. By building this executable, we get a command line interface. We pass our command and arguments, just as we would when using command line `git`, and we read the results from the standard output.

Just like we in the example above have the line:

`await Module.callMain(['clone', 'https://wasm-git.petersalomonsen.com/pixeldrawing', 'pixeldrawing']);`

We can call the same command with the standard `git` command line client:

`git clone https://wasm-git.petersalomonsen.com/pixeldrawing pixeldrawing`

To get the understanding of what happens when we call this command we should look at the `examples/clone.c` file in the libgit2 repository. Here we see the following line:

`error = git_clone(&cloned_repo, url, path, &clone_opts);`

While this might seem like a simple straight forward function to call on the lbigit2 API, as mentioned above, it is quite more complex to call this if it is exposed as a direct WebAssembly export. The first parameter is a pointer to a `git_repository` struct, and the last is a pointer to a `git_clone_options`. Allocating a pointer could be done easily with `malloc`, but then initializing the callbacks in the `git_clone_options` is more complicated from Javascript. We see these lines here in the C code for initializing these options:

```C
clone_opts.fetch_opts.callbacks.sideband_progress = sideband_progress;
clone_opts.fetch_opts.callbacks.transfer_progress = &fetch_progress;
clone_opts.fetch_opts.callbacks.credentials = cred_acquire_cb;
clone_opts.fetch_opts.callbacks.payload = &pd;
```

The callback pointers are function pointers. These functions also need to be inside the WebAssembly binary, and so we are not be able to initialize this struct from Javascript.

Because of this, the least effort when it comes to interacting with this particular WebAssembly module, is by passing data that are easily parsed on both sides. Because of Emscripten, we also have the file system as a point of interaction, and we can even intercept and implement the network transport. The C API of Libgit2 is a different world from Javascript, so it is not straight forward to connect these two directly. Building on the CLI examples as the interface to Javascript is a way that is maintainable with small efforts. We can expect this interface to evolve and be compatible for future versions of Libgit2, since it is aligned with the standard git Command Line Interface.

# Making the web app accessible when disconnected from the internet

The last line of the example earlier in this chapter contains a reference to a `ServiceWorker`. 

`await navigator.serviceWorker.register('serviceworker.js', { scope: './' });`

We would like to serve web apps from an internet domain, and not from localhost. So even if we can host the app from localhost, and work with the data when disconnected from the internet, we also want the application itself to be cached in the browser. A service worker is a mechanism in modern browsers that is between the web application and the network. It can control the cache and respond with cached results if the network is not reachable, and we can make it respond with custom errors when trying to synchronize data.

A simple serviceworker looks like this:

```javascript
const cachesVersion = '2023-12-28';

const noCacheUrlBeginnings = [
  'https://wasm-git.petersalomonsen.com'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.open(cachesVersion).then(cache =>
      cache.match(event.request).then((resp) => {        
        return resp || fetch(event.request).then((response) => {
          if (
            noCacheUrlBeginnings.findIndex(urlBeginning =>
              event.request.url.indexOf(urlBeginning) === 0)
            === -1
          ) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      }).catch((err) => {
        return new Response(null, { status: 500, statusText: err.message });
      })
    )
  );
});
```

We are not going to explain the serviceworker API and code in detail, but we can see here that we cache everything except the responses from the git server at https://wasm-git.petersalomonsen.com. 

The result is that we can reach a cached version of web application when offline. Synchronization of data with the git server will fail, but will work again when back online.

# Conclusion

We have seen how to port a large C library like Libgit2 to WebAssembly, and also how to interact with it from Javascript. The Javascript way is asynchronuous, which is often not compatible with how we write synchronuous code in C. Emscripten provides the Asyncify feature, or we can use a web worker with synchronous networking to adapt. The API of a  C library like Libgit2 is not straightforward to expose as WebAssembly exports for use from Javascript, and we need to use for example a Command Line Interface approach in combination with the Emscripten file systems to interact with the library. We have also been studying a real-world use case of Wasm git to provide a web application that is available offline, and making use of Git technology to synchronize data with a remote server.

In the next chapter we will look at the language which is considered a viable alternative to C and C++. Rust provides the same low level system interaction capabilities as C / C++, across many platforms. It comes with an approach where we can catch many programming errors at compile time, rather than having to experience defects that may be hard to debug. Rust is also popular for creating WebAssembly applications, and we will demonstrate why that is the case in the next and later chapters in this book. 

# Points to remember

- When porting a library or application to WebAssembly that use networking, we may have to provide a separate implementation for using the Web APIs for network requests.
- A C library may reference structs and callbacks that are not straightforward to manage from Javascript, and so we have to provide higher level methods of interacting with the library:
    - Command Line Interface
    - Using the Emscripten file system for exchanging data between Javascript and WebAssembly
- Git, or the WebAssembly port of Libgit2 called "wasm-git" can be used for providing offline data capabilities to a Web application, and use the mechanisms of Git to synchronize with a remote server
- Git is an efficient versioned data storage for any kind of data that can be written in text files. Especially JSON data.
