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
