use std::{vec::Vec, ffi::CString};
use ed25519_dalek::{Signer, SigningKey};
static mut SCRIPT: Option<Vec<u8>> = None;

extern "C" {
    fn create_runtime();
    fn js_eval(javascript_source: *const u8) -> i64;
    fn js_get_string(jsvalue: i64) -> *const u8;
    fn js_add_global_function(function_name: i32, function_impl: i32, num_params: i32);
    fn JS_ToCStringLen2(ctx: i32, value_len_ptr: i32, val: i64, b: i32) -> i32;
    fn JS_NewStringLen(ctx: i32, buf: i32, buf_len: usize) -> i64;
    fn JS_GetArrayBuffer(ctx: i32, buf_len_ptr: i32, value_ptr: i64) -> *const u8;
    fn JS_NewArrayBuffer(ctx: i32, buf_ptr: i32, buf_len: i32, free_func: i32, opaque: i32, is_shared: i32) -> i64;
}

unsafe fn add_global_function(
    function_name: &str,
    function_impl: fn(i32, i64, i32, i32) -> i64,
    num_params: i32,
) {
    let function_name_cstr = CString::new(function_name).unwrap();
    js_add_global_function(
        function_name_cstr.as_ptr() as i32,
        function_impl as i32,
        num_params,
    );
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
        // Clear the previous script if it exists to prevent memory leaks
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

#[no_mangle]
pub extern "C" fn init() {
    unsafe {
        create_runtime();
        add_global_function("helloFromRust", 
            |ctx: i32, _this_val: i64, _argc: i32, _argv: i32| -> i64 {

            let result = "Hello from Rust";
            return JS_NewStringLen(ctx, result.as_ptr() as i32, result.len());
        }, 0);
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
    }
}

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
            init();
            let script_slice = std::slice::from_raw_parts_mut(scriptptr, script_len);
            script_slice.copy_from_slice(script);
            let result = CStr::from_ptr(run_js().cast());
            assert_eq!("{\"value\":\"hello\"}", result.to_str().unwrap());
        }
    }

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
}
