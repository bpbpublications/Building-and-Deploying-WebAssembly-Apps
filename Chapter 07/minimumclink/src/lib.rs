use wasm_bindgen::prelude::*;

extern "C" {
    fn add(a: i32, b: i32) -> i32;
}

#[wasm_bindgen]
pub fn add_numbers(a: i32, b: i32) -> i32 {
    unsafe {
        return add(a,b);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    pub fn test_add_numbers() {        
        assert_eq!(5, add_numbers(2, 3));        
    }
}
