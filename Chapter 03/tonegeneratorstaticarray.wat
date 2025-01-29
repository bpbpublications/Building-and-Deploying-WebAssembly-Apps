(module
 (type $none_=>_none (func))
 (type $f32_=>_none (func (param f32)))
 (type $none_=>_i32 (func (result i32)))
 (global $tonegeneratorstaticarray/_step (mut f32) (f32.const 0))
 (global $tonegeneratorstaticarray/_val (mut f32) (f32.const 0))
 (memory $0 1)
 (export "setFrequency" (func $tonegeneratorstaticarray/setFrequency))
 (export "fillSampleBuffer" (func $tonegeneratorstaticarray/fillSampleBuffer))
 (export "memory" (memory $0))
 (start $~start)
 (func $tonegeneratorstaticarray/setFrequency (param $0 f32)
  local.get $0
  f32.const 44100
  f32.div
  global.set $tonegeneratorstaticarray/_step
 )
 (func $~lib/staticarray/StaticArray<f32>#get:length (result i32)
  i32.const 1020
  i32.load $0
  i32.const 2
  i32.shr_u
 )
 (func $tonegeneratorstaticarray/fillSampleBuffer
  (local $0 i32)
  (local $1 f32)
  loop $for-loop|0
   call $~lib/staticarray/StaticArray<f32>#get:length
   local.get $0
   i32.gt_s
   if
    global.get $tonegeneratorstaticarray/_val
    global.get $tonegeneratorstaticarray/_step
    f32.add
    global.set $tonegeneratorstaticarray/_val
    global.get $tonegeneratorstaticarray/_val
    local.tee $1
    local.get $1
    f32.trunc
    f32.sub
    local.get $1
    f32.copysign
    global.set $tonegeneratorstaticarray/_val
    global.get $tonegeneratorstaticarray/_val
    f32.const -0.5
    f32.add
    local.set $1
    call $~lib/staticarray/StaticArray<f32>#get:length
    local.get $0
    i32.le_u
    if
     unreachable
    end
    local.get $0
    i32.const 2
    i32.shl
    i32.const 1024
    i32.add
    local.get $1
    f32.store $0
    local.get $0
    i32.const 1
    i32.add
    local.set $0
    br $for-loop|0
   end
  end
 )
 (func $~start
  i32.const 1020
  i32.const 512
  i32.store $0
 )
)
