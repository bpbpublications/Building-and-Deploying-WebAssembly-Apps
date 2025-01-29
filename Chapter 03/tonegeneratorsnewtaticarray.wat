(module
 (type $none_=>_none (func))
 (type $f32_=>_none (func (param f32)))
 (type $i32_=>_i32 (func (param i32) (result i32)))
 (global $tonegeneratornewstaticarray/samplebuffer (mut i32) (i32.const 0))
 (global $tonegeneratornewstaticarray/_step (mut f32) (f32.const 0))
 (global $tonegeneratornewstaticarray/_val (mut f32) (f32.const 0))
 (memory $0 1)
 (export "samplebuffer" (global $tonegeneratornewstaticarray/samplebuffer))
 (export "setFrequency" (func $tonegeneratornewstaticarray/setFrequency))
 (export "fillSampleBuffer" (func $tonegeneratornewstaticarray/fillSampleBuffer))
 (export "memory" (memory $0))
 (start $~start)
 (func $tonegeneratornewstaticarray/setFrequency (param $0 f32)
  local.get $0
  f32.const 44100
  f32.div
  global.set $tonegeneratornewstaticarray/_step
 )
 (func $~lib/staticarray/StaticArray<f32>#get:length (param $0 i32) (result i32)
  local.get $0
  i32.const 20
  i32.sub
  i32.load $0 offset=16
  i32.const 2
  i32.shr_u
 )
 (func $tonegeneratornewstaticarray/fillSampleBuffer
  (local $0 i32)
  (local $1 f32)
  (local $2 i32)
  loop $for-loop|0
   global.get $tonegeneratornewstaticarray/samplebuffer
   call $~lib/staticarray/StaticArray<f32>#get:length
   local.get $0
   i32.gt_s
   if
    global.get $tonegeneratornewstaticarray/_val
    global.get $tonegeneratornewstaticarray/_step
    f32.add
    global.set $tonegeneratornewstaticarray/_val
    global.get $tonegeneratornewstaticarray/_val
    local.tee $1
    local.get $1
    f32.trunc
    f32.sub
    local.get $1
    f32.copysign
    global.set $tonegeneratornewstaticarray/_val
    global.get $tonegeneratornewstaticarray/_val
    f32.const -0.5
    f32.add
    local.set $1
    global.get $tonegeneratornewstaticarray/samplebuffer
    local.tee $2
    call $~lib/staticarray/StaticArray<f32>#get:length
    local.get $0
    i32.le_u
    if
     unreachable
    end
    local.get $2
    local.get $0
    i32.const 2
    i32.shl
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
  (local $0 i32)
  (local $1 i32)
  memory.size $0
  local.tee $0
  i32.const 16
  i32.shl
  i32.const 15
  i32.add
  i32.const -16
  i32.and
  local.tee $1
  i32.const 556
  i32.lt_u
  if
   local.get $0
   i32.const 66091
   local.get $1
   i32.sub
   i32.const -65536
   i32.and
   i32.const 16
   i32.shr_u
   local.tee $1
   local.get $0
   local.get $1
   i32.gt_s
   select
   memory.grow $0
   i32.const 0
   i32.lt_s
   if
    local.get $1
    memory.grow $0
    i32.const 0
    i32.lt_s
    if
     unreachable
    end
   end
  end
  i32.const 12
  i32.const 540
  i32.store $0
  i32.const 16
  i32.const 0
  i32.store $0
  i32.const 20
  i32.const 0
  i32.store $0
  i32.const 24
  i32.const 4
  i32.store $0
  i32.const 28
  i32.const 512
  i32.store $0
  i32.const 32
  i32.const 0
  i32.const 512
  memory.fill $0
  i32.const 32
  global.set $tonegeneratornewstaticarray/samplebuffer
 )
)
