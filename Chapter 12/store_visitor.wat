(module
  ;; params: value_len, value_ptr
  (import "env" "value_return" (func $value_return (param i64 i64)))
  ;; params: key_len, key_ptr, value_len, value_ptr, register_id
  (import "env" "storage_write" (func $storage_write (param i64 i64 i64 i64 i64) (result i64)))
  ;; params: key_len, key_ptr, register_id
  (import "env" "storage_read" (func $storage_read (param i64 i64 i64) (result i64)))
  ;; params: register, ptr
  (import "env" "read_register" (func $read_register (param i64 i64)))
  ;; params: register_id, result: len
  (import "env" "register_len" (func $register_len (param i64) (result i64)))
  ;; params: register_id
  (import "env" "signer_account_id" (func $signer_account_id (param i64)))
  (func (export "visit")    
    (call $signer_account_id (i64.const 0)) ;; read signer_account_id into register 0)
    (call $read_register (i64.const 0) (i64.const 2048))  ;; read register 0 contents into memory addr 2048
    (call $storage_write
      ( i64.const 7 ) ;; length of key named "visitor"
      ( i64.const 1024 );; address of key named "visitor"
      (call $register_len (i64.const 0)) ;; get length of contents in register 0
      ( i64.const 2048 ) ;; address that we stored registered 0 contents into
      ( i64.const 0 )
    )
    drop
  )
  (func (export "last_visitor")
    (call $storage_read
      ( i64.const 7 ) ;; length of key named "visitor"
      ( i64.const 1024 );; address of key named "visitor"
      ( i64.const 0 );; store result in register 0
    )
    (i32.store8 (i32.add (i32.const 2048) (i32.wrap_i64 (call $register_len (i64.const 0)))) (i32.const 34)) ;; store character " at memory addr 2048 + content length
    (call $read_register (i64.const 0) (i64.const 2048)) ;; read contents of register 0 into memory addr 2048
    drop
    (call $value_return (i64.add (i64.const 2) (call $register_len (i64.const 0))) (i64.const 2047)) ;; return value with 2 + length of register 0 contents, at memory addr 2047
  )
  (memory 1)  
  (data (i32.const 1024) "visitor") ;; blockchain storage key
  (data (i32.const 2047) "\"") ;; first character of returned result when calling "last_visitor"
)
