(module  
  (import "env" "js_before" (func $js_before))
  (import "env" "js_after" (func $js_after (param i32)))
  (import "env" "js_timeout" (func $js_timeout (param i32) (result i32)))
  (memory 1 1)
  (export "memory" (memory 0))
  (func $sleep (export "sleep") (param $duration i32) (result i32) 
    (local $result i32)
    call $js_before
    local.get $duration
    call $js_timeout
    local.tee $result
    call $js_after
    local.get $result
  )
)