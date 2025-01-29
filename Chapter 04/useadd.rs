#![crate_type = "cdylib"]
#![no_std]
use core::panic::PanicInfo;
use core::arch::wasm32;

#[panic_handler]
fn handle_panic(_info: &PanicInfo) -> ! {
    wasm32::unreachable()
}

extern "C" {
    fn get_base_value() -> i32;
}

extern "C" {
    fn add(a: i32, b: i32) -> i32;
}

#[no_mangle]
pub extern "C" fn getBaseValue() -> i32 {
    unsafe {
        return get_base_value();
    }
}

#[no_mangle]
pub extern "C" fn useadd(a: i32, b: i32) -> i32 {
    unsafe {
        return add(a,b);
    }
}
