(module
  (type (;0;) (func (param i32) (result i32)))
  (type (;1;) (func (param i32 i32) (result i32)))
  (func (;0;) (type 0) (param i32) (result i32)
    local.get 0
    local.get 0
    i32.add)
  (func (;1;) (type 0) (param i32) (result i32)
    local.get 0
    local.get 0
    i32.mul)
  (func (;2;) (type 1) (param i32 i32) (result i32)
    local.get 0
    i32.const 0
    i32.lt_s
    local.get 0
    i32.const 2
    i32.ge_s
    i32.or
    if  ;; label = @1
      i32.const -1
      return
    end
    local.get 0
    i32.const 140
    i32.load
    i32.ge_u
    if  ;; label = @1
      unreachable
    end
    i32.const 132
    i32.load
    local.get 0
    i32.const 2
    i32.shl
    i32.add
    i32.load
    local.tee 0
    i32.eqz
    if  ;; label = @1
      unreachable
    end
    local.get 1
    local.get 0
    i32.load
    call_indirect (type 0))
  (table (;0;) 3 3 funcref)
  (memory (;0;) 1)
  (export "compute" (func 2))
  (elem (;0;) (i32.const 1) func 0 1)
  (data (;0;) (i32.const 12) "\1c")
  (data (;1;) (i32.const 24) "\04\00\00\00\08\00\00\00\01")
  (data (;2;) (i32.const 44) "\1c")
  (data (;3;) (i32.const 56) "\04\00\00\00\08\00\00\00\02")
  (data (;4;) (i32.const 76) "\1c")
  (data (;5;) (i32.const 88) "\01\00\00\00\08\00\00\00 \00\00\00@")
  (data (;6;) (i32.const 108) ",")
  (data (;7;) (i32.const 120) "\05\00\00\00\10\00\00\00`\00\00\00`\00\00\00\08\00\00\00\02"))
