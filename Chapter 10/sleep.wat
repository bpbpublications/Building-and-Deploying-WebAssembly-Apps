(module
  (import "env" "current_time" (func $current_time (result i32)))
  (func $sleep (param $duration i32)
    local.get $duration
    call $current_time
    i32.add
    local.set $duration
    loop $while_sleeping
      call $current_time
      local.get $duration
      i32.lt_s
      br_if $while_sleeping
    end
  )
  (export "sleep" (func $sleep))
)