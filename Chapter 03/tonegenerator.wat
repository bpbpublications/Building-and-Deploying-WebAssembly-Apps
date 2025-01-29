(module
 (type $f32_=>_none (func (param f32)))
 (type $none_=>_none (func))
 (global $tonegenerator/_step (mut f32) (f32.const 0))
 (global $tonegenerator/_val (mut f32) (f32.const 0))
 (memory $0 1)
 (export "setFrequency" (func $tonegenerator/setFrequency))
 (export "fillSampleBuffer" (func $tonegenerator/fillSampleBuffer))
 (export "memory" (memory $0))
 (func $tonegenerator/setFrequency (param $0 f32)
  local.get $0
  f32.const 44100
  f32.div
  global.set $tonegenerator/_step
 )
 (func $tonegenerator/fillSampleBuffer
  (local $0 i32)
  (local $1 f32)
  i32.const 1024
  local.set $0
  loop $for-loop|0
   local.get $0
   i32.const 1536
   i32.lt_s
   if
    global.get $tonegenerator/_val
    global.get $tonegenerator/_step
    f32.add
    global.set $tonegenerator/_val
    global.get $tonegenerator/_val
    local.tee $1
    local.get $1
    f32.trunc
    f32.sub
    local.get $1
    f32.copysign
    global.set $tonegenerator/_val
    local.get $0
    global.get $tonegenerator/_val
    f32.const -0.5
    f32.add
    f32.store $0
    local.get $0
    i32.const 4
    i32.add
    local.set $0
    br $for-loop|0
   end
  end
 )
)
