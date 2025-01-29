(module
  (import "env" "value_return" (func $value_return (param i64 i64)))
  (func (export "web4_get")
    i64.const 63
    i64.const 0
    call $value_return
  )
  (memory 1)
  (data (i32.const 0) "{\"contentType\": \"text/html; charset=UTF-8\", \"body\": \"aGVsbG8K\"}")
)
