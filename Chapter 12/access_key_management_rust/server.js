import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import nearApi from 'near-api-js';

const contractId = 'youraccount.testnet';
const near = await nearApi.connect({
    networkId: 'testnet',
    contractId,
    nodeUrl: 'https://rpc.testnet.near.org'
});

const server = createServer(async (req, res) => {
    if (req.url == '/api') {
        const token_bytes = Buffer.from(req.headers.authorization.substring('Bearer '.length), 'base64');
        const token_payload = JSON.parse(new TextDecoder().decode(token_bytes));
        const token_hash = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", token_bytes)));

        const contract = new nearApi.Contract(await near.account(), 'youraccount.testnet', {
            viewMethods: ['get_token_permission_for_resource']
        });

        try {
            const permission = await contract.get_token_permission_for_resource({ token_hash, resource_id: token_payload.resource_id });
            res.write(`Your permission to ${token_payload.resource_id} is: ${permission}`);
        } catch (e) {
            res.write(e.toString());
        }
        res.end();
    } else {
        res.write(await readFile('app.html'));
        res.end();
    }
});
server.listen(15000);
