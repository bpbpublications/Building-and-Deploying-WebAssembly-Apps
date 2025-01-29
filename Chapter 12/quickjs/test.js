const currentTime = new Date();

const html = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
<h1>Hello from QuickJS inside a NEAR smart contract!</h1>
<p>On the blockchain, the current time is ${currentTime} and the current number of blocks processed is ${block_index()}.</p>
</body>
</html>
`;

({"contentType": "text/html; charset=UTF-8", "body": base64_encode(html)});