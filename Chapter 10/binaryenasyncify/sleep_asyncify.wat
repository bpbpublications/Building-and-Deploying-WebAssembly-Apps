(module
 (type $i32_=>_none (func (param i32)))
 (type $none_=>_none (func))
 (type $i32_=>_i32 (func (param i32) (result i32)))
 (type $none_=>_i32 (func (result i32)))
 (import "env" "js_before" (func $js_before))
 (import "env" "js_after" (func $js_after (param i32)))
 (import "env" "js_timeout" (func $js_timeout (param i32) (result i32)))
 (global $__asyncify_state (mut i32) (i32.const 0))
 (global $__asyncify_data (mut i32) (i32.const 0))
 (memory $0 1 1)
 (export "memory" (memory $0))
 (export "sleep" (func $sleep))
 (export "asyncify_start_unwind" (func $asyncify_start_unwind))
 (export "asyncify_stop_unwind" (func $asyncify_stop_unwind))
 (export "asyncify_start_rewind" (func $asyncify_start_rewind))
 (export "asyncify_stop_rewind" (func $asyncify_stop_unwind))
 (export "asyncify_get_state" (func $asyncify_get_state))
 (func $sleep (; has Stack IR ;) (param $0 i32) (result i32)
  (local $1 i32)
  (local $2 i32)
  (if
   (i32.eq
    (global.get $__asyncify_state)
    (i32.const 2)
   )
   (block
    (i32.store
     (global.get $__asyncify_data)
     (i32.sub
      (i32.load
       (global.get $__asyncify_data)
      )
      (i32.const 4)
     )
    )
    (local.set $0
     (i32.load
      (i32.load
       (global.get $__asyncify_data)
      )
     )
    )
   )
  )
  (local.set $2
   (block $__asyncify_unwind (result i32)
    (if
     (i32.eq
      (global.get $__asyncify_state)
      (i32.const 2)
     )
     (block
      (i32.store
       (global.get $__asyncify_data)
       (i32.sub
        (i32.load
         (global.get $__asyncify_data)
        )
        (i32.const 4)
       )
      )
      (local.set $1
       (i32.load
        (i32.load
         (global.get $__asyncify_data)
        )
       )
      )
     )
    )
    (if
     (i32.eqz
      (select
       (local.get $1)
       (i32.const 0)
       (global.get $__asyncify_state)
      )
     )
     (block
      (call $js_before)
      (drop
       (br_if $__asyncify_unwind
        (i32.const 0)
        (i32.eq
         (global.get $__asyncify_state)
         (i32.const 1)
        )
       )
      )
     )
    )
    (if
     (select
      (i32.eq
       (local.get $1)
       (i32.const 1)
      )
      (i32.const 1)
      (global.get $__asyncify_state)
     )
     (block
      (local.set $2
       (call $js_timeout
        (local.get $0)
       )
      )
      (drop
       (br_if $__asyncify_unwind
        (i32.const 1)
        (i32.eq
         (global.get $__asyncify_state)
         (i32.const 1)
        )
       )
      )
      (local.set $0
       (local.get $2)
      )
     )
    )
    (if
     (select
      (i32.eq
       (local.get $1)
       (i32.const 2)
      )
      (i32.const 1)
      (global.get $__asyncify_state)
     )
     (block
      (call $js_after
       (local.get $0)
      )
      (drop
       (br_if $__asyncify_unwind
        (i32.const 2)
        (i32.eq
         (global.get $__asyncify_state)
         (i32.const 1)
        )
       )
      )
     )
    )
    (if
     (i32.eqz
      (global.get $__asyncify_state)
     )
     (return
      (local.get $0)
     )
    )
    (unreachable)
   )
  )
  (i32.store
   (i32.load
    (global.get $__asyncify_data)
   )
   (local.get $2)
  )
  (i32.store
   (global.get $__asyncify_data)
   (i32.add
    (i32.load
     (global.get $__asyncify_data)
    )
    (i32.const 4)
   )
  )
  (i32.store
   (i32.load
    (global.get $__asyncify_data)
   )
   (local.get $0)
  )
  (i32.store
   (global.get $__asyncify_data)
   (i32.add
    (i32.load
     (global.get $__asyncify_data)
    )
    (i32.const 4)
   )
  )
  (i32.const 0)
 )
 (func $asyncify_start_unwind (; has Stack IR ;) (param $0 i32)
  (global.set $__asyncify_state
   (i32.const 1)
  )
  (global.set $__asyncify_data
   (local.get $0)
  )
  (if
   (i32.gt_u
    (i32.load
     (global.get $__asyncify_data)
    )
    (i32.load offset=4
     (global.get $__asyncify_data)
    )
   )
   (unreachable)
  )
 )
 (func $asyncify_stop_unwind (; has Stack IR ;)
  (global.set $__asyncify_state
   (i32.const 0)
  )
  (if
   (i32.gt_u
    (i32.load
     (global.get $__asyncify_data)
    )
    (i32.load offset=4
     (global.get $__asyncify_data)
    )
   )
   (unreachable)
  )
 )
 (func $asyncify_start_rewind (; has Stack IR ;) (param $0 i32)
  (global.set $__asyncify_state
   (i32.const 2)
  )
  (global.set $__asyncify_data
   (local.get $0)
  )
  (if
   (i32.gt_u
    (i32.load
     (global.get $__asyncify_data)
    )
    (i32.load offset=4
     (global.get $__asyncify_data)
    )
   )
   (unreachable)
  )
 )
 (func $asyncify_get_state (; has Stack IR ;) (result i32)
  (global.get $__asyncify_state)
 )
)
