use ed25519_dalek::{Signature, Signer, SigningKey};
use std::convert::TryInto;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn sign_message(message: &[u8], secret_key_bytes: &[u8]) -> Result<Vec<u8>, JsValue> {
    if secret_key_bytes.len() != 64 {
        return Err(JsValue::from_str("Secret key must be 64 bytes long"));
    }

    let secret_key_array: &[u8; 64] = secret_key_bytes.try_into().unwrap(); // safe to unwrap here due to the length check above

    let signing_key = SigningKey::from_keypair_bytes(secret_key_array)
        .map_err(|e| JsValue::from_str(&format!("Invalid key: {}", e)))?;

    let signature: Signature = signing_key.sign(message);

    Ok(signature.to_bytes().to_vec())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    pub fn test_sign_message() {
        let message = b"hello";
        let secret_key: [u8; 64] = [
            254, 114, 130, 212, 33, 69, 193, 93, 12, 15, 108, 76, 19, 198, 118, 148, 193, 62, 78,
            4, 9, 157, 188, 191, 132, 137, 188, 31, 54, 103, 246, 191, 62, 57, 59, 247, 76, 246,
            60, 248, 227, 133, 30, 160, 254, 106, 146, 229, 101, 149, 245, 6, 148, 125, 124, 102,
            49, 14, 108, 234, 201, 122, 62, 159,
        ];

        // Convert secret_key array to slice
        let secret_key_slice: &[u8] = &secret_key;

        // Call the sign_message function
        let result = sign_message(message, secret_key_slice);

        // Check if the result is Ok and contains the expected signature
        match result {
            Ok(signature) => {
                let expected_signature: [u8; 64] = [
                    95, 215, 84, 162, 41, 169, 4, 227, 39, 241, 140, 48, 65, 236, 149, 58, 146,
                    109, 35, 77, 1, 85, 7, 44, 186, 226, 174, 250, 173, 210, 216, 163, 216, 35,
                    100, 178, 130, 13, 37, 8, 70, 150, 212, 194, 137, 40, 247, 7, 208, 108, 178,
                    192, 86, 219, 53, 104, 166, 51, 186, 100, 27, 15, 3, 3,
                ];
                assert_eq!(signature, expected_signature);
            }
            Err(e) => panic!("Error occurred: {:?}", e),
        }
    }
}
