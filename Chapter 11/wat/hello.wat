(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (func (export "_start")
    i32.const 1
    i32.const 0
    i32.const 1
    i32.const 100
    call $fd_write
    drop
  )
  (memory (export "memory") 1)
  (data (i32.const 0) "\08\00\00\00\07\00\00\00hello\n\00")
)
