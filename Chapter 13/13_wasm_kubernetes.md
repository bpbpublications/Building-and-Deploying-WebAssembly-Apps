# Deploying and Running WebAssembly Applications on Kubernetes

# Introduction

Cloud Native technology is about much more than running software on a remote virtual machine, hosted by some tech giant cloud provider. When writing software for the Cloud Native target, we want to be able to "drop it" there, and it should run without worries. Even though many have been introduced to cloud computing, through virtual machines that can be started easily from a web portal, the real difference is when you can ship your application and make it run without having to administrate a server. It is even better if the server that is running the software, can be taken down without taking down your application. In cloud "Platform as a Service" offerings, servers are replaced, scaled up and down automatically, and still the deployed software keeps on running, without disruption for the end user. Downtime caused by server crashes or upgrades is a forgotten chapter in the past, the software can just "jump" to a server that is up and ready to serve the end user.

Cloud Native is the technology that delivers these features. Deploying to a cloud native infrastructure is about sending a list of manifests, declaring the list of software that should be up and running, and then the cluster of servers is orchestrated by the cloud native technology implementation. The software will be automatically installed and started on server nodes that are capable to run it, and moved or replicated across multiple servers if needed.

Kubernetes is one of the systems, with many implementations by different providers, delivering fully on the Cloud Native principles. Almost any server software can run on Kubernetes. Databases, event streaming platforms, search engines, language models, microservices, you name it.

Software deployed to Kubernetes are packaged as containers, typically built using Docker. These containers are small standalone operating system instances, dedicated to the hosted application. While you can run many types of applications inside a Docker container, including WebAssembly runtimes, the footprint when it comes to resource usage could be smaller. Even if the compute resources are much more efficiently used than with standalone servers or virtual machines, there still are millions of Kubernetes nodes today, with containers running idle while waiting for a request to serve. Microservices running in containers have a server process in at least one instance. They occupy a substantial part of memory, which means servers have to keep running, even if there is no activity. This results in hosting costs, electricity usage and an environmental footprint that is still so significant that we can benefit substantially by finding ways to reduce it.

One of the reasons that a microservice container needs to be running, is the startup time. If we were to start it when the request arrives, there would be delays that degrades the user experience. One of the key features of WebAssembly is fast startup. In this book we have seen that many types of applications, written in several languages, can be packaged as a WebAssembly binary. Cloud Native platforms leverage this in the form of WebAssembly containers. The WebAssembly Component model that we looked at in chapter 11 also facilitates a "Serverless" execution model through WASI HTTP handler. We can use this in Cloud Native infrastructures like Kubernetes to load the application when a request arrives, and terminate it once served. While traditional "Serverless" often involves loading some applications instances for standby, WebAssembly components can load on demand.

Being able to load on demand, and shut down when not in use, means that we can reduce hosting costs and environmental impact. We can do more with less resources.

# Structure

- WebAssembly containers
- Deploying to Kubernetes
- Scaling to zero
- An AI image classification service
- Including file assets with the AI service
- Calling external network resources, authenticating with the smart contract
- Deploying to a public cloud Kubernetes service

# Objectives

In this chapter we will follow up on the things we learned in both chapter 11 and 12. You will see how the WebAssembly component model applies to WebAssembly containers in Cloud Native hosting. We will look into packaging a WebAssembly container image using "Fermyon Spin", and also how to build new applications with it. You will learn how to use KEDA, the event driven auto-scaler for Kubernetes, with the HTTP addon to scale to zero when applications are idle. We will create an AI image classification service in WebAssembly, and we will include static file assets to serve a HTML frontend from it, and also call an external HTTP service. We will revisit the smart contract in chapter 12 for access control. You will learn how to deploy the WebAssembly app to a locally hosted K3D Kubernetes and a public Azure Kubernetes service.

# WebAssembly containers

To make full use of a container orchestration platform like Kubernetes, we must be able to reference container images in our deployment manifests. We want to reference a WebAssembly container image the same way we reference a Docker image. WebAssembly container images can be pushed to container registries just like Docker images, and we can point to their URLs from Kubernetes deployment manifests.

In chapter 11 we looked at the WebAssembly Component model, and we implemented a HTTP handler component. We can package this component into a WebAssembly container, and deploy it to Kubernetes.

A tool that can help us packaging WebAssembly containers is `spin`. Go to https://developer.fermyon.com/spin/v2/install to find installation instructions.

After installing spin, let us copy the `httphandler_composed.wasm` that we created in chapter 11 into a new folder where we also add a file that we name `spin.toml` with the following contents:

```
spin_manifest_version = 2

[application]
name = "music"
version = "0.1.0"

[[trigger.http]]
route = "/music"
component = "music"

[[trigger.http]]
route = "/mul"
component = "music"

[component.music]
description = "My music app"
source = "httphandler_composed.wasm"
```

If we make this new folder our current directory, we can easily start our `httphandler_composed.wasm` component in the `spin` runtime by typing:

```bash
spin up
```

Our component will be available from the localhost, and you can invoke the same URLs as we had in chapter 11 when using `wasmtime serve`.

`spin` is more than a runtime to run our WebAssembly components. It is a complete framework for building and publishing them. For example, without further modifications, we can push our current component to a container registry.

Below is an example command for pushing to the github container registry `ghcr.io`. To be able to do that you need to create a personal access token with package write permission under "developer settings" on github.

You can then login to the registry by typing:

```bash
spin registry login ghcr.io
```

provide your github username and the access token, and then you can push the application:


```bash
spin registry push ghcr.io/my_github_account/music
```

If you navigate to packages under your github profile, and change visibility for your newly deployed package to public, then anyone with spin installed can run your application by typing:

```bash
spin up -f ghcr.io/my_github_account/music:latest
```

As you can see, spin can perfectly run the application on its own too, without any container orchestration infrastructure like Kubernetes. However, when we want to deploy this at scale, together with other services and applications, and maybe multiple instances of it, we can really benefit from the orchestration capabilities of Kubernetes.

# Deploying to Kubernetes

As of today, support for WebAssembly containers in Kubernetes is not yet out of the box. Our cluster needs to be configured to run Wasm workloads. The cluster must be set up to use a WebAssembly runtime for running the Wasm containers.

For testing this, we can set up the lightweight Kubernetes distribution "K3D" from Rancher Lab, for which we can find images that has the Wasm "shims" already installed.

Go to https://k3d.io and find installation instructions for K3D.

After installing k3d you can find the instructions for creating a K3D Kubernetes cluster in the "SpinKube" documentation at https://www.spinkube.dev/docs/spin-operator/quickstart/

The important part of this document is the creation of the cluster which we can do using this command:

```bash
k3d cluster create wasm-cluster --image ghcr.io/spinkube/containerd-shim-spin/k3d:v0.13.1 -p "8081:80@loadbalancer" --agents 2
```

And then we also need to apply the `RuntimeClass` for "Spin", named `wasmtime-spin-v2`, which can be done by applying the runtime declaration file from the SpinKube github repository:

```bash
kubectl apply -f https://github.com/spinkube/spin-operator/releases/download/v0.1.0/spin-operator.runtime-class.yaml
```

Now we can create a regular Kubernetes deployment declaration, with the only difference that we specify the `wasmtime-spin-v2` runtime class, as you can see from the `runtimeClassName` field below.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: musicandmul
spec:
  replicas: 1
  selector:
    matchLabels:
      app: musicandmul
  template:
    metadata:
      labels:
        app: musicandmul
    spec:
      runtimeClassName: wasmtime-spin-v2
      containers:
        - name: musicandmul
          image: ghcr.io/my_github_account/music:latest
          command: ["/"]
---
apiVersion: v1
kind: Service
metadata:
  name: musicandmul
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  selector:
    app: musicandmul
```

If we save this in a file named `musicandmul.yaml`, we can apply it to the cluster by typing:

```bash
kubectl apply -f musicandmul.yaml
```

Let us also try to connect to it. Since we have no ingress in our cluster, we must port-forward into the service

```bash
kubectl port-forward svc/wasm-music 8080:80
```

And then from another terminal, we can download the wav file that will be produced by the `/music` endpoint:

```bash
curl http://localhost:8080/music -o music.wav
```

We can also go to http://localhost:8080/mul and see the result of the `mul` module.

# Scaling to zero

Now that we have a deployment let us also test the startup time of a WebAssembly pod. KEDA (https://keda.sh/) is an event driven autoscaler for Kubernetes. For example, it can scale number of instances in a deployment based on the number of pending messages in a queue. An interesting project, currently in BETA state, is the HTTP addon for KEDA, which you can find at https://github.com/kedacore/http-add-on. This can scale based on incoming HTTP traffic, which makes it possible to scale from zero to 1. If we can scale from zero, we can also scale down to zero when there is no incoming HTTP activity.

It is very common in a Kubernetes cluster that there are deployed multiple instances of the same application. A Software as a Service provider may offer their application as one dedicated instance per customer, and so they have a running container for each of them. It is often not the case that these customer environments have incoming HTTP traffic simultaneously. Still they occupy memory on the node, since they keep on running. If we could shut them down, we could fit even more customer environments on the same node, since they don't need to be active simultaneously all the time.

Let us try this by installing KEDA with the HTTP addon on our cluster. We will use the HELM (https://helm.sh/) package manager for this.

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda -n keda --create-namespace
helm install http-add-on kedacore/keda-add-ons-http --set interceptor.responseHeaderTimeout=5000ms --namespace keda
```

These 4 commands install both `keda` and the `http-add-on` in a namespace called `keda`. Note the `interceptor.responseHeaderTimeout=5000ms` value in the last line, which is for an example later in this chapter, where it will take some time to respond since we will create an API for image classification, and it will also call the NEAR smart contract from the previous chapter for access control.

We should also add some lines to our `musicandmul.yaml` file above to declare a `HTTPScaledObject`:

```yaml
kind: HTTPScaledObject
apiVersion: http.keda.sh/v1alpha1
metadata:
    name: musicandmul
spec:
    hosts:
    - myhost.com
    pathPrefixes:
    - /mul
    - /music
    scaleTargetRef:
        name: musicandmul
        kind: Deployment
        apiVersion: apps/v1
        service: musicandmul
        port: 80
    scaledownPeriod: 5
    replicas:
        min: 0
        max: 1
```

The `HTTPScaledObject` specify a host `myhost.com` and some path prefixes which in this case are `/mul` and `/music`. Under `scaleTargetRef` we point to our `musicandmul` deployment and service. We set the `scaledownPeriod` to 5 seconds, which means that our deployment will scale to zero if there is no incoming HTTP traffic within 5 seconds. Number of replicas are either `0` (min) or `1` (max). We will use this setting just to demonstrate the concept of scaling to zero. In a production scenario we could set the `max` to a number that represents the expected maximum load.

Use the `kubectl apply -f musicandmul.yaml` command to configure the new resource in the cluster.

In the `keda` namespace there is a service called `keda-add-ons-http-interceptor-proxy`. If we set up an ingress, we should route http traffic that we want to scale automatically to this interceptor proxy service. For now we we will just port-forward to the interceptor service with the following command:

```bash
kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy 8080:8080
```

When the port-forwarding is active, you can open another terminal to connect to the forwarded port. We use `curl` since we need to pass the `Host` header, and we are connecting to localhost rather than the actual hostname.

```bash
curl -H "Host: myhost.com" http://localhost:8080/mul
```

After a few seconds you should see the response, and if you are fast, you can also see that there is one running pod by typing `kubectl get pods`. When the `scaledownPeriod` of 5 seconds has passed, the pod will shut down, and when you then try to get the list of pods, there will be none active.

We can also download the music wav file:

```bash
 curl -H "Host: myhost.com" http://localhost:8080/music -o music.wav
```

What we have seen here is full scaling to zero, meaning that there is no pods running at all when there is no incoming http traffic. It does not take many seconds for the user to get response even from a cold start like this. If we don't want the users to wait at all, we can keep the WebAssembly pods running. Even if we don't scale to zero pod instances, the `wasmtime-spin-v2` runtime will unload the WebAssembly instance when the http request has completed. The "Spin" runtime will instantiate a new WebAssembly instance for each incoming http request, and unload it when done. Spin does scale to zero WebAssembly instances even if the pod is still running. The benefit of this is that the HTTP listener will keep running, and since instantiating a WebAssembly module just takes a few milliseconds, it can be done when the HTTP listener receives a request. The user will not notice that a application instance was instantiated just to serve that single request.

# An AI image classification service

Let us create a new application that is larger, occupies more memory, and use more CPU. We will embed an AI model for image classification into our WebAssembly binary, and we want to see the impact on startup time. Since this service will use more than 100MB of memory when loaded, we will benefit from being able to scale it down to zero.

In this example we will use the `spin` framework for creating the new application.

```bash
spin new
```

Select the `http-rust` template, and type the name description and HTTP pattern which can be `/imageclassify` in this case. This will set up a Rust project with `src/lib.rs`, `Cargo.toml` and `spin.toml`.

To build it we can type `spin build`, and `spin up` to run it locally.

Now let us add our AI code. First we need to add `image` and `tract-onnx` as dependencies to `Cargo.toml`:

```
[dependencies]
anyhow = "1"
spin-sdk = "2.2.0"
image = "0.25.1"
tract-onnx = "0.21.2"

[profile.release]
lto = true
opt-level = 'z'
debug = false
strip = 'symbols'
```

Now to the application code, which in this case is a modified version of the example in the Sonos "Tract" github respository, which you can find here: https://github.com/sonos/tract/tree/main/examples/onnx-mobilenet-v2. The example is modified to get the image data from the HTTP post body, instead of reading from a file. Also the result is returned as the HTTP response.

```rust
use anyhow::Result;
use spin_sdk::{
    http::{IntoResponse, Request, Response},
    http_component,
};
use std::io::Cursor;
use tract_onnx::prelude::*;

const MODEL: &'static [u8] = include_bytes!("../static/mobilenetv2-7.onnx");

#[http_component]
async fn handle_imageclassify(req: Request) -> Result<impl IntoResponse> {
    let model = tract_onnx::onnx()
        .model_for_read(&mut Cursor::new(MODEL))?
        .into_optimized()?
        .into_runnable()?;

    let image_bytes = req.body();

    let image = image::load_from_memory(image_bytes).unwrap().to_rgb8();

    let resized =
        image::imageops::resize(&image, 224, 224, ::image::imageops::FilterType::Triangle);
    let image: Tensor = tract_ndarray::Array4::from_shape_fn((1, 3, 224, 224), |(_, c, y, x)| {
        let mean = [0.485, 0.456, 0.406][c];
        let std = [0.229, 0.224, 0.225][c];
        (resized[(x as _, y as _)][c] as f32 / 255.0 - mean) / std
    })
    .into();

    let result = model.run(tvec!(image.into()))?;

    let best = result[0]
        .to_array_view::<f32>()?
        .iter()
        .cloned()
        .zip(2..)
        .max_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    Ok(Response::builder()
        .status(200)
        .header("content-type", "text/plain")
        .body(format!("result: {best:?}"))
        .build())
}
```

You can also see the reference to the file `../mobilenetv2-7.onnx` which you will need to obtain as described in the URL above to the Sonos Tract example on github. You should create a folder named `static` and put the model file in there.

We can build it using `spin build`, and start it locally by running `spin up`.

To test it we can download the image file of Grace Hopper in uniform which also can be find in the github repository, and use `curl` to upload the data to our service.

```bash
curl --data-binary @grace_hopper.jpg http://localhost:3000/imageclassify
```

This should give us the result:

```bash
result: Some((12.4404125, 654))
```

To understand what this result means, take note of the number `654` in the result, and go back to https://github.com/sonos/tract/tree/main/examples/onnx-mobilenet-v2 where you can find a file named `imagenet_slim_labels.txt`. Scroll down to line 654 in this file where you can see the text `military uniform`, which is indeed what the picture is showing. You can look at the other items in this file, and try to find good pictures of it to test the AI service.

The next step is to deploy it to Kubernetes, where we can use the `spinkube` plugin to scaffold the deployment for us. We an also follow the same recipie as above, just creating a deployment and service, but here we will also show the "Spin operator" in action. The Spin operator gives us a new Resource type in Kubernetes called `SpinApp`, and deploying this will automatically create the `Deployment` and `Service` resource for us.

Let us first publish our new app to the container registry:

```bash
spin registry push ghcr.io/my_github_account/imageclassify
```

Then we can create our `spin_deployment.yaml` file, simply by typing:

```bash
spin kube scaffold -f ghcr.io/my_github_account/imageclassify -o spin_deployment.yaml
```

We have now got a file named `spin_deployment.yaml` with the following contents:

```yaml
apiVersion: core.spinoperator.dev/v1alpha1
kind: SpinApp
metadata:
  name: imageclassify
spec:
  image: "ghcr.io/my_github_account/imageclassify"
  executor: containerd-shim-spin
  replicas: 2
```

To be able to deploy this, we must install the spin operator, which you may already have done if you followed all the steps in the documentation that we referred to above: https://www.spinkube.dev/docs/spin-operator/quickstart/

After the spin operator is installed we can deploy our app from the terminal by typing:

```bash
kubectl apply -f spin_deployment.yaml
```

We can now connect to the service using port-forwarding by typing:

```bash
kubectl port-forward svc/imageclassify 8080:80
```

And then in another terminal we can test it:

```bash
curl --data-binary @grace_hopper.jpg http://localhost:3000/imageclassify
```

We can see that this particular service takes some seconds to respond. Image classification is a computing intensive task, so the delay for the response is only because of the time computation of the classification result takes. We can also see that this particular pod occupies quite a bit of memory even when there are no requests. By running the command `kubectl top pods` we can see a memory usage of around `150Mi`. This is because of the size of the WebAssembly file, which is preloaded into memory by the Spin runtime. Even if a Wasm module instance is created and destroyed for every HTTP request, the binary is still there, occupying memory.

With such a large module we can benefit from the KEDA `HTTPScaledObject`. We can easily apply this by extending our `spin_deployment.yaml` file.

```yaml
apiVersion: core.spinoperator.dev/v1alpha1
kind: SpinApp
metadata:
  name: imageclassify
spec:
  image: "ghcr.io/my_github_account/imageclassify"
  executor: containerd-shim-spin
  enableAutoscaling: true
---
kind: HTTPScaledObject
apiVersion: http.keda.sh/v1alpha1
metadata:
    name: imageclassify
spec:
    hosts:
    - myhost.com
    pathPrefixes:
    - /imageclassify
    scaleTargetRef:
        name: imageclassify
        kind: Deployment
        apiVersion: apps/v1
        service: imageclassify
        port: 80
    scaledownPeriod: 5
    replicas:
        min: 0
        max: 1
```

As you can see the change is now that we have removed the specification of the number of `replicas`, and instead inserted `enableAutoscaling: true`. We have also added the `HTTPScaledObject` declaration as we did in the previous example above.

If we deploy this, we can see that there are no pods. It will be created when we make a request. Again we will connect to the `keda-add-ons-http-interceptor-proxy` instead of the `imageclassify` service, since it is the interceptor proxy that triggers scaling of the imageclassify deployment.

We connect through port-forwarding:

```bash
kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy 8080:8080
```

And then in another terminal, we send a request by typing:

```bash
curl -H "Host: myhost.com" -X POST -H "Content-Type: application/octet-stream" --data-binary @grace_hopper.jpg http://localhost:8080/imageclassify
```

It may take some extra seconds when the pod also has to start, but in this case it is not so much difference compared to the time used by the image classification application itself.

# Including file assets with the AI service

To reduce the idle memory footprint of the spin pod, we can exclude the model file from the Wasm binary, and rather include it as a file asset in the distributed container image. Since the WebAssembly code is running in a WASI environment, it does also have access to loading file assets through the WASI interfaces, and so we do not have to use any special APIs to access them. The `tract_onnx` library, which is a generic Rust library and has no knowledge that it is running in a WASI environment, has a function to load a model file from a path. We can use that function directly.

We can remove the following line from `src/lib.rs`:

```rust
const MODEL: &'static [u8] = include_bytes!("../static/mobilenetv2-7.onnx");
```

And we can replace `.model_for_read(&mut Cursor::new(MODEL))?` with `.model_for_path("models/mobilenetv2-7.onnx")?`. Instead of reading the model from the static memory of the WebAssembly binary, we now read it from a file.

The lines for reading the model, should now look like this:

```rust
let model = tract_onnx::onnx()
              .model_for_path("models/mobilenetv2-7.onnx")?
              .into_optimized()?
              .into_runnable()?;
```

As we saw in chapter 11, WASI runtimes does not give access to files without explicitly providing information to the runtime about which files or directories the WebAssembly application should be able to access. For the Spin runtime we declare this in `spin.toml`.

Under the `[component.imageclassify]` section in `spin.toml` we can add a line for `files`:

```
files = [ { source = "static/", destination = "/" } ]
```

We have stored the model file in our local `static`, but for the application we want the file to be available at the root level as we specify with the `destination` property.

Since this is a web application, we should also include a frontend. We can add a static html file `imageclassify.html` with a image file upload input. We can serve this html file through our application. Since our image classification API expects the HTTP `POST` method, we can return the HTML file if the method is `GET`.

We can add the following right after the `handle_imageclassify` function declaration:

```rust
  if req.method().to_owned() == Method::Get {
        return Ok(Response::builder()
            .status(200)
            .header("content-type", "text/html")
            .body(fs::read_to_string("imageclassify.html").unwrap())
            .build()
        )
  }
```

The `handle_imageclassify` function will now return the contents of `imageclassify.html` if the method is `GET`.

And we also need to create the `imageclassify.html` file, which we will also place in the `static` folder. We will base it on the access control example in chapter 12, since we will use this for authenticating with our AI service. Our "off-chain" API in this case will be the image classification service.

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
    <div>
        <button id="signin_button">Sign in</button>
        <button id="signout_button">Sign out <span id="signedin_account_span"></span></button>
        <button id="generate_token_button">Generate token</button>
        <button id="register_token_button">Register token</button>
    </div>
    <div>
        <input type="file" id="imagefileupload" accept="image/png, image/jpeg"><br />
        <img id="uploadedimage"><br />
        <button id="call_offchain_api_button">Classify image</button>
    </div>
    <h3>Result</h3>
    <pre><code id="resultarea"></code></pre>
</body>
<script src="https://cdn.jsdelivr.net/npm/near-api-js@3.0.4/dist/near-api-js.min.js"></script>
<script type="module">
    const contractId = 'youraccount.testnet';
    const near = await nearApi.connect({
        networkId: 'testnet',
        keyStore: new nearApi.keyStores.BrowserLocalStorageKeyStore(),
        contractId,
        nodeUrl: 'https://rpc.testnet.near.org',
        walletUrl: 'https://testnet.mynearwallet.com/'
    });

    const walletConnection = new nearApi.WalletConnection(near, 'my-app');
    const signInButton = document.getElementById('signin_button');
    const signoutButton = document.getElementById('signout_button');
    const signedInAccountSpan = document.getElementById('signedin_account_span');
    const generateTokenButton = document.getElementById('generate_token_button');
    const registerTokenButton = document.getElementById('register_token_button');
    const callOffchainAPIButton = document.getElementById('call_offchain_api_button');
    const resultArea = document.getElementById('resultarea');

    if (await walletConnection.isSignedInAsync()) {
        signInButton.style.display = 'none';
        signoutButton.style.display = 'block';
        signedInAccountSpan.innerHTML = walletConnection.getAccountId();
    } else {
        signInButton.style.display = 'block';
        signoutButton.style.display = 'none';
    }

    signInButton.addEventListener('click', async () => {
        await walletConnection.requestSignIn({ contractId });
    });
    signoutButton.addEventListener('click', async () => {
        await walletConnection.signOut();
        signInButton.style.display = 'block';
        signoutButton.style.display = 'none';
    });

    const resource_id = 'mytestresource';
    let token_bytes;

    generateTokenButton.addEventListener('click', async () => {
        const token_uuid = crypto.randomUUID();
        const token_string = JSON.stringify({ resource_id, token_uuid });
        token_bytes = new TextEncoder().encode(token_string);
        resultArea.innerText = token_string;
    });

    registerTokenButton.addEventListener('click', async () => {
        registerTokenButton.disabled = true;
        try {
            resultArea.innerText = 'Please wait while registering token';
            const signature = Array.from((await near.connection.signer.signMessage(token_bytes, walletConnection.getAccountId(), 'testnet')).signature);
            const token_hash = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", token_bytes)));

            const contract = new nearApi.Contract(walletConnection.account(), contractId, {
                changeMethods: ['register_token']
            });

            const result = await contract.register_token({ token_hash, signature });
            resultArea.innerText = JSON.stringify(result, null, 1);
        } catch (e) {
            resultArea.innerText = e.toString();
        }
        registerTokenButton.disabled = false;
    });

    const fileUploadInput = document.getElementById('imagefileupload');
    const uploadedImage = document.getElementById('uploadedimage');
    fileUploadInput.addEventListener('change', () => {
        uploadedImage.src = URL.createObjectURL(fileUploadInput.files[0]);
    });

    callOffchainAPIButton.addEventListener('click', async () => {
        const token_bytes_base64 = btoa(Array.from(token_bytes, (byte) =>
            String.fromCodePoint(byte),
        ).join(""));
        const fileData = await new Promise(resolve => {
            const fileReader = new FileReader();
            fileReader.onload = () => resolve(fileReader.result);
            fileReader.readAsArrayBuffer(fileUploadInput.files[0])
        });
        resultArea.innerText = await fetch('/imageclassify', {
            method: 'POST',
            headers: { Authorization: `Bearer ${token_bytes_base64}` },
            body: fileData
        }).then(r => r.text());
    });
</script>
</html>
```

The changes we have done in the HTML part is to add a file upload element that accepts an image. We have added a image element for previewing, and moved the button for calling the off-chain API below the image.

```html
    <div>
        <input type="file" id="imagefileupload" accept="image/png, image/jpeg"><br />
        <img id="uploadedimage"><br />
        <button id="call_offchain_api_button">Classify image</button>
    </div>
```

In the Javascript code we have added an event listener for the file upload input element, which updates the image element to show the image that we have provided.

```javascript
  const fileUploadInput = document.getElementById('imagefileupload');
    const uploadedImage = document.getElementById('uploadedimage');
    fileUploadInput.addEventListener('change', () => {
        uploadedImage.src = URL.createObjectURL(fileUploadInput.files[0]);
  });
```

We have inserted this handler just before the button handler for calling the off-chain API, the `/imageclassify` endpoint in this case. There are also some additions to this button handler, since we want to send the image to the API. As you can see we use a `FileReader` to read the image file contents into an `ArrayBuffer` that we name `fileData`. We provide `fileData` in to the request `body` when calling `imageclassify`, and we have also specified the `POST` method.

```javascript
  callOffchainAPIButton.addEventListener('click', async () => {
        const token_bytes_base64 = btoa(Array.from(token_bytes, (byte) =>
            String.fromCodePoint(byte),
        ).join(""));
        const fileData = await new Promise(resolve => {
            const fileReader = new FileReader();
            fileReader.onload = () => resolve(fileReader.result);
            fileReader.readAsArrayBuffer(fileUploadInput.files[0])
        });
        resultArea.innerText = await fetch('/imageclassify', {
            method: 'POST',
            headers: { Authorization: `Bearer ${token_bytes_base64}` },
            body: fileData
        }).then(r => r.text());
    });
```

We can test this locally using `spin up`, and by entering http://localhost:3000 in a web browser, we can see the web page. We are able to classify images, even if we have not signed in. This is because we have not implemented the access control in our API yet, but we still need to click the "Generate token" button before classifying an image, since our client code expects to have an access token to send to the API. In a real life application we would hide for the user generating the token and registering it, but we keep it in our example here just to highlight all the steps in the application flow.

![Image classification app running locally](imageclassifyapp.png)

Another thing to notice here is the classification result. Rather than showing `result: Some((17.785063, 314))`, it would be better to show what `314` is. Let us add the file `imagenet_slim_labels.txt` to our file assets as well.

First let us download it from the Sonos `tract` github repository and store it in the `static` folder:

```bash
curl https://raw.githubusercontent.com/sonos/tract/main/examples/onnx-mobilenet-v2/imagenet_slim_labels.txt -o static/image_slim_labels.txt
```

We should also make use of it when returning the result from our `/imageclassify` API endpoint. In `src/lib.rs`, just before returning the response, we will read the file `image_slim_labels.txt`, split it into lines, and look up the line number returned by the AI model. We will return the contents of that line as the response body.

Here is the modified last part of our `handle_imageclassify` function:

```rust
  let labels = fs::read_to_string("image_slim_labels.txt").unwrap();
  let lines: Vec<&str> = labels.lines().collect();
  let line_number = best.unwrap().1 - 1;
  let result = lines[line_number];

  Ok(Response::builder()
      .status(200)
      .header("content-type", "text/plain")
      .body(result)
      .build())
```

If we now try to classify the image from the browser, we can see that it returns the result `cricket` if using the image from the screenshot above, or `military uniform` if classifying the picture of Grace Hopper.

Now let us also add the access control, which involves making a network request to an external service.

# Calling external network resources, authenticating with the smart contract

Making external network requests are not yet part of the WASI standard so we will use the proprietary Spin function `spin_sdk::http::send`. In chapter 12 we implemented a server in nodejs for decoding the access token passed in the `authorization` request header, hashing it using `sha256` and making a request to the `get_token_permission_for_resource` method of the smart contract on the NEAR protocol testnet. If the smart contract has the token hash stored in connection with the requested resource id, it returns the access level for the provided token hash. Now we will implement the same functionality in Rust, inside our imageclassify WebAssembly binary.

We will create a new file named `src/auth.rs`, a separate Rust module for the authentication.

```rust
use base64::prelude::*;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use spin_sdk::http::{send, Method, Request, Response};
use std::str;

pub async fn check_access(auth_header: &str) -> bool {
    let token_bytes = BASE64_STANDARD
        .decode(&auth_header["Bearer ".len()..])
        .unwrap();
    let token_str = str::from_utf8(&token_bytes).unwrap();

    let resource_name = "mytestresource";
    let token_payload: Value = serde_json::from_str(token_str).unwrap();
    if token_payload["resource_id"] != resource_name {
        return false;
    }

    let mut hasher = Sha256::new();
    hasher.update(&token_bytes);
    let token_hash = hasher.finalize();

    let token_hash_bytes: Vec<u8> = token_hash.iter().map(|&b| b).collect();

    let json_object = json!({
        "token_hash": token_hash_bytes,
        "resource_id": resource_name
    });

    let args = serde_json::to_string(&json_object).unwrap();
    let args_base64 = BASE64_STANDARD.encode(args.as_bytes());
    let request_body_json_object = json!({
        "jsonrpc": "2.0",
        "id": "dontcare",
        "method": "query",
        "params": {
            "request_type": "call_function",
            "finality": "final",
            "account_id": "youraccount.testnet",
            "method_name": "get_token_permission_for_resource",
            "args_base64": args_base64
        }
    });

    let request = Request::builder()
        .method(Method::Post)
        .uri("https://rpc.testnet.near.org/")
        .header("content-type", "application/json")
        .body(serde_json::to_string(&request_body_json_object).unwrap())
        .build();

    let response: Response = send(request).await.unwrap();
    let response_body: Value = serde_json::from_slice(response.body()).unwrap();
    if response_body["result"]["result"].as_array().is_some() {
        return true;
    } else {
        return false;
    }
}
```

This file provides the function `check_access` which we should provide with the contents of the `authorization` header. The function will skip the first `Bearer ` part, and extract the access token from the string. Since the token is base64 encoded from the client, we will decode it into a byte array. We will also decode the byte array to a String so that we can parse the JSON to extract the requested `resource_id`. We want to make sure that the user attempts to access the resource we have named `mytestresource`, and if not we will return `false`, indicating that access is denied. If the `resource_id` matches, then we will hash the `token_bytes` using `sha256`. As in chapter 12, we will not send the actual token to the smart contract, since this should be a secret between the user and the API. We send the hash, and the requested resource, asking the smart contract if the token is registered, and about the access level to the requested resource. We do not use any library for NEAR here, since the payload for calling a smart contract view method is quite simple. The only thing we have to do, which the Javascript library did for us in the nodejs server example, is that we have to base64 encode the parameters to the smart contract view function call. The JSON string created in the `args` variable is encoded into base64 in the `args_base64` variable. We build the request and use the `send` function to call the NEAR RPC API at https://rpc.testnet.near.org/, and if the returned JSON contains the `result.result` property, then we return `true`, granting access. If the token is not registered, or there is no permission for the requested resource connected to it, then the call to the smart contract will fail, and there will be no `result.result` property, and then we return `false`, denying access.

Finally let's connect it into the `handle_imageclassify` function in `src/lib.rs`.

We need to reference the new `auth` module:

```rust
mod auth;
use auth::check_access;
```

and we need to call the `check_access` function, which we can do after checking for the `GET` method and returning the HTML contents:

```rust
  if !check_access(req.header("authorization").unwrap().as_str().unwrap()).await {
      return Ok(Response::builder()
          .status(403)
          .header("content-type", "text/plain")
          .body(format!("Access denied"))
          .build());
  }
```

Our complete `src/lib.rs` now looks like this:

```rust
use anyhow::Result;
use spin_sdk::{
    http::{IntoResponse, Method, Request, Response},
    http_component,
};
use tract_onnx::prelude::*;
mod auth;
use auth::check_access;
use std::fs;

#[http_component]
async fn handle_imageclassify(req: Request) -> Result<impl IntoResponse> {
    if req.method().to_owned() == Method::Get {
        return Ok(Response::builder()
            .status(200)
            .header("content-type", "text/html")
            .body(fs::read_to_string("imageclassify.html").unwrap())
            .build()
        )
    }

    if !check_access(req.header("authorization").unwrap().as_str().unwrap()).await {
        return Ok(Response::builder()
            .status(403)
            .header("content-type", "text/plain")
            .body(format!("Access denied"))
            .build());
    }

    let model = tract_onnx::onnx()
        .model_for_path("mobilenetv2-7.onnx")?
        .into_optimized()?
        .into_runnable()?;

    let image_bytes = req.body();

    let image = image::load_from_memory(image_bytes).unwrap().to_rgb8();

    let resized =
        image::imageops::resize(&image, 224, 224, ::image::imageops::FilterType::Triangle);
    let image: Tensor = tract_ndarray::Array4::from_shape_fn((1, 3, 224, 224), |(_, c, y, x)| {
        let mean = [0.485, 0.456, 0.406][c];
        let std = [0.229, 0.224, 0.225][c];
        (resized[(x as _, y as _)][c] as f32 / 255.0 - mean) / std
    })
    .into();

    let result = model.run(tvec!(image.into()))?;

    let best = result[0]
        .to_array_view::<f32>()?
        .iter()
        .cloned()
        .zip(2..)
        .max_by(|a, b| a.0.partial_cmp(&b.0).unwrap());

    let labels = fs::read_to_string("image_slim_labels.txt").unwrap();
    let lines: Vec<&str> = labels.lines().collect();
    let line_number = best.unwrap().1 - 1;
    let result = lines[line_number];

    Ok(Response::builder()
        .status(200)
        .header("content-type", "text/plain")
        .body(result)
        .build())
}
```

For all this to work, we also need some new dependencies in `Cargo.toml`:

```
base64 = "0.22.0"
serde = "1.0.197"
serde_json = "1.0.115"
sha2 = "0.10.8"
```

Remember to build with `spin build`, before you restart the app with `spin up`. If we now only generate a token without registering it, we will get the result `Access denied`. If we register the token, and then try again to classify the image, then we will get the classification result.

# Deploying to a public cloud Kubernetes service

We can deploy this to the K3D cluster that we already have, but it is also interesting to try it on a public cloud Kubernetes such as the "Azure Kubernetes Service" ( AKS ).

There is a tutorial for installing SpinKube in AKS at https://www.spinkube.dev/docs/spin-operator/tutorials/deploy-on-azure-kubernetes-service/, and you should follow this tutorial up to the point of "Deploying a Spin App to AKS", where you should continue back here. You go through the steps of provisioning the Azure resources, the Kubernetes cluster, installing the `cert-manager`, `kwasm-operator`, `spin-operator` and create the `shim-executor`. Compared to the steps from K3D, where we have container images preloaded with `containerd-shim-spin`, it is "KWasm" that is responsible for installing this on AKS.

Before we can deploy, we should publish our app to the container registry, and we will use the github registry as we have done above.

```bash
spin registry push ghcr.io/my_github_account/imageclassify:0.1.0
```

Notice that we specify a version `0.1.0` which helps so that the Kubernetes cluster does not have to check for the latest version each time the pod starts.

We can use the same `spinapp.yaml` as we did above for K3D.

```yaml
apiVersion: core.spinoperator.dev/v1alpha1
kind: SpinApp
metadata:
  name: imageclassify
spec:
  image: "ghcr.io/my_github_account/imageclassify:0.1.0"
  executor: containerd-shim-spin
  replicas: 2
```

We deploy it with `kubectl apply -f spinapp.yaml`, and if we port-forward using

```bash
kubectl port-forward svc/imageclassify 8080:80
```

then we can access the web-page at http://localhost:8080/imageclassify.

You can also add the `HttpScaledObject` for adding the automatic scaling as we did above. Our `spinapp.yaml` will then look like this:

```yaml
apiVersion: core.spinoperator.dev/v1alpha1
kind: SpinApp
metadata:
  name: imageclassify
spec:
  image: "ghcr.io/my_github_account/imageclassify:0.1.0"
  executor: containerd-shim-spin
  enableAutoscaling: true
  resources:
    limits:
      cpu: 500m
      memory: 256Mi
---
kind: HTTPScaledObject
apiVersion: http.keda.sh/v1alpha1
metadata:
    name: imageclassify
spec:
    hosts:
    - localhost
    pathPrefixes:
    - /
    scaleTargetRef:
        name: imageclassify
        kind: Deployment
        apiVersion: apps/v1
        service: imageclassify
        port: 80
    scaledownPeriod: 5
    replicas:
        min: 0
        max: 1
```

And as above we will then portforward to the KEDA http addon interceptor proxy:

```bash
kubectl port-forward -n keda svc/keda-add-ons-http-interceptor-proxy 8080:8080
```

And from a web-browser we can access the web page at http://localhost:8080/imageclassify

# Conclusion

We have wrapped up what we learned from the last 3 chapters into deploying a WebAssembly application to a cloud native hosting infrastructure. WebAssembly container images can be pushed to a container registry, just like Docker container image, but they are different in many ways, such as that WebAssembly images does not consist of an operating system and file system structure. WebAssembly containers are lighter, they start fast, which makes it possible to scale to zero and still resume quickly from the zero state. Scaling to zero makes it possible to utilize the compute resources more efficient, since idle pods would otherwise occupy compute resources such as memory which limits the number of applications we can deploy to one node. Keeping the WebAssembly runtime and http listener running, will make the startup time almost instant, without a delay for the end user to notice. This we could also see in the previous chapter with WebAssembly blockchain smart contracts hosting web applications. Also there the WebAssembly applications are created when requested, and the delay compared to a stateful running web application is hardly noticable to the user. From the way we can see how this already works on the NEAR protocol blockchain, we can also expect this to improve even more with the WebAssembly containers on Kubernetes. We can expect to have options for the WebAssembly runtimes to completely unload the WebAssembly modules from memory when idle. Not just the instances as we see with the current free offering Fermyon Spin. WebAssembly technology makes this complete cooldown feature possible.

WebAssembly container applications can access static file assets and make HTTP calls to external services. This we could see through the AI image classification example, where we also used the NEAR blockchain smart contract for checking user access. 

We have deployed WebAssembly containers to a local K3D Kubernetes cluster, and the public cloud Azure Kubernetes Service. The "Spin" framework and runtime provides a complete toolset for running WebAssembly applications in the cloud native world. There are also already other alternatives, and we can expect more to come, and also we can expect native support for WebAssembly containers in Kubernetes distributions in the future.

WebAssembly has changed the Web. It has increased the selection of applications we can use in a web browser. In this chapter we have also seen how it will change the server side, and how it will increase the possibilities of maximizing the potential of Cloud Native technology.

# Points to remember

- WebAssembly containers are light and starts fast
- Fast startup opens up for scaling down when the application is idle
- A WebAssembly runtime must be configured for which files and external network hosts the application is allowed to access, unlike Docker containers which by default have full access to container files and network.
- There are two approaches for scaling to zero on Kubernetes
  - One is to fully scale down with no pods running, minimizing idle memory usage, with the penalty of an extra second of pod startup time
  - The other is to let the WebAssembly runtime take care of it. Spin creates and tears down the WebAssembly instances for each request, and also have offerings to fully unload the WebAssembly module from memory when idle.
- WebAssembly is a compile target for many applications, throughout the book we have seen codebases not specifically designed for WebAssembly, and the AI library used in this chapter is no exception. Yet WebAssembly allows to easily embed such libraries to create all kinds of applications.

# Exercises

- Hide the `Generate token` and `Register token` buttons for the user, and make it automatically happen in the background. Only generate and register the token for the first invocation of `/imageclassify`.