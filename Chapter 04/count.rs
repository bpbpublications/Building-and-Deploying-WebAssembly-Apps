#![crate_type = "cdylib"]
#![no_std]
use core::panic::PanicInfo;
use core::arch::wasm32;

#[panic_handler]
fn handle_panic(_info: &PanicInfo) -> ! {
    wasm32::unreachable()
}

#[no_mangle]
pub extern "C" fn countto100() -> i32 {
    let mut n = 0;
    while n < 100 {
        n += 1;
    }
    n
}
