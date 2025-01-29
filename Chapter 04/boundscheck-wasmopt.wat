(module
  (type (;0;) (func (param i32) (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    local.get 0
    i32.const 1
    i32.le_u
    if (result i32)  ;; label = @1
      local.get 0
      i32.const 2
      i32.shl
      i32.const 1024
      i32.add
      i32.load
    else
      i32.const -1
    end)
  (memory (;0;) 2)
  (export "memory" (memory 0))
  (export "boundscheck" (func 0))
  (data (;0;) (i32.const 1024) "d\00\00\00\c8"))
