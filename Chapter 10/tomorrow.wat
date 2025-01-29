(module
  (import "env" "current_time" (func $current_time (result i32)))

  (func $tomorrow (result i32)
    call $current_time
    i32.const 86400
    i32.add
  )
  (export "tomorrow" (func $tomorrow))
)