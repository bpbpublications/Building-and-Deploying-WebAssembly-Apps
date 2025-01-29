(module
  (func $mul (param $a i32) (param $b i32) (result i32)
    local.get $a
    local.get $b
    i32.mul)
  (export "example:multiply/multiplier#mul" (func $mul))
)