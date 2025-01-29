use crate::bindings::Guest;

mod bindings;
use bindings::my::mul::multiplier::mul;

struct Component;

impl  bindings::Guest for Component {
    fn add(x: i32, y: i32) -> i32 {
        x + y
    }
}

impl bindings::exports::wasi::cli::run::Guest for Component {
    fn run() -> Result<(),()> {
        let operation_successful = true; // Dummy condition

        let result = Component::add(5, 8);
        let mulresult = mul(5, 8);
        println!("Add {}", result);
        println!("Mul {}", mulresult);
        if operation_successful {
            Ok(())
        } else {
            Err(())
        }
    }
}

