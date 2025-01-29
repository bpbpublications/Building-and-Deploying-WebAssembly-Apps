(module
  (import "env" "current_time" (func $current_time (result i32)))
  (import "env" "timeout" (func $timeout (param i32)))
  (global $start_time (mut i32) (i32.const 0))
  (func $sleep (param $duration i32)
    call $current_time
    global.set $start_time
    local.get $duration
    call $timeout
  )
  (func $sleep_callback (result i32)
    call $current_time
    global.get $start_time    
    i32.sub
  )
  (export "sleep" (func $sleep))
  (export "sleep_callback" (func $sleep_callback))
)
