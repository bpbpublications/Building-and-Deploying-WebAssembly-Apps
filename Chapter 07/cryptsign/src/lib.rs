use ed25519_dalek::{Signer, SigningKey};

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

            // Copy the signing key to the location pointed to by signing_key_ptr
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
