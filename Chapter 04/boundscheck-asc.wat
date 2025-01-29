(module
  (type (;0;) (func (param i32) (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    local.get 0
    i32.const 76
    i32.load
    i32.ge_u
    if  ;; label = @1
      unreachable
    end
    i32.const 68
    i32.load
    local.get 0
    i32.const 2
    i32.shl
    i32.add
    i32.load)
  (memory (;0;) 1)
  (export "boundscheck" (func 0))
  (data (;0;) (i32.const 12) "\1c")
  (data (;1;) (i32.const 24) "\01\00\00\00\08\00\00\00d\00\00\00\c8")
  (data (;2;) (i32.const 44) ",")
  (data (;3;) (i32.const 56) "\04\00\00\00\10\00\00\00 \00\00\00 \00\00\00\08\00\00\00\02"))
