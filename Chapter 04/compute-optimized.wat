(module
  (type (;0;) (func (param i32) (result i32)))
  (type (;1;) (func (param i32 i32) (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    local.get 0
    i32.const 1
    i32.shl)
  (func (;1;) (type 0) (param i32) (result i32)
    local.get 0
    local.get 0
    i32.mul)
  (func (;2;) (type 1) (param i32 i32) (result i32)
    local.get 0
    i32.const 1
    i32.le_u
    if (result i32)  ;; label = @1
      local.get 1
      local.get 0
      i32.const 2
      i32.shl
      i32.const 1024
      i32.add
      i32.load
      call_indirect (type 0)
    else
      i32.const -1
    end)
  (table (;0;) 3 3 funcref)
  (memory (;0;) 2)
  (export "memory" (memory 0))
  (export "compute" (func 2))
  (elem (;0;) (i32.const 1) func 0 1)
  (data (;0;) (i32.const 1024) "\01\00\00\00\02"))
