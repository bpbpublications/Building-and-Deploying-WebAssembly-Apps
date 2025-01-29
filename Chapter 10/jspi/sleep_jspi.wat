(module  
  (import "env" "js_before" (func $js_before))
  (import "env" "js_after" (func $js_after (param i32)))
  (import "env" "js_timeout" (func $js_timeout_import (param externref) (param i32) (result i32)))
  (global $suspender (mut externref) (ref.null extern))
  (func $js_timeout (param $duration i32) (result i32)
    (global.get $suspender)
    (local.get $duration)
    (call $js_timeout_import)
  )
  (func $sleep (param $duration i32) (result i32) 
    (local $result i32)
    call $js_before
    local.get $duration
    call $js_timeout
    local.tee $result
    call $js_after
    local.get $result
  )
  (func $sleep_export (export "sleep") 
    (param $susp externref)
    (param $duration i32)(result i32)
    (local.get $susp)
    (global.set $suspender)
    (local.get $duration)
    (return_call $sleep)
  )
)
