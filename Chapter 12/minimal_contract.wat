(module
  (import "env" "value_return" (func $value_return (param i64 i64)))
  (func (export "hello")
    i64.const 7
    i64.const 0
    call $value_return
  )
  (memory 1)
  (data (i32.const 0) "\"hello\"")
)
