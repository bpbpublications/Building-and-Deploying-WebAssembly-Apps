#include "./quickjs-2024-01-13/quickjs.h"
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <wasi/api.h>

JSValue global_obj;
JSRuntime *rt = NULL;
JSContext *ctx;

static const char b64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char STORAGE_KEY[] = "j";
const int64_t STORAGE_KEY_LEN = 1;

extern void value_return(int64_t value_len, int64_t value_ptr);
extern void input(int64_t register_id);
extern void read_register(int64_t register_id, int64_t data_ptr);
extern int64_t register_len(int64_t register_id);
extern int64_t storage_write(int64_t key_len, int64_t key_ptr, int64_t value_len, int64_t value_ptr, int64_t register_id);
extern int64_t storage_read(int64_t key_len, int64_t key_ptr, int64_t register_id);
extern int64_t block_timestamp();
extern int64_t block_index();

__wasi_errno_t __wasi_clock_time_get(__wasi_clockid_t id, __wasi_timestamp_t precision, __wasi_timestamp_t *time)
{
    *time = block_timestamp();
    return 0;
}

__wasi_errno_t __wasi_fd_close(__wasi_fd_t fd)
{
    return 0;
}
__wasi_errno_t __wasi_environ_sizes_get(__wasi_size_t *environ_count, __wasi_size_t *environ_buf_size)
{
    return 0;
}
__wasi_errno_t __wasi_fd_write(
    __wasi_fd_t fd,
    const __wasi_ciovec_t *iovs,
    size_t iovs_len,
    __wasi_size_t *nwritten)
{
    return 0;
}

__wasi_errno_t __wasi_fd_seek(__wasi_fd_t fd, __wasi_filedelta_t offset, __wasi_whence_t whence, __wasi_filesize_t *newoffset)
{
    return 0;
}
void __wasi_proc_exit(__wasi_exitcode_t rval)
{
    abort();
}

__wasi_errno_t __wasi_environ_get(uint8_t **environ, uint8_t *environ_buf)
{
    return 0;
}

void base64_encode(const char *data, char *encoded)
{
    int i, j;
    size_t len = strlen(data);
    for (i = 0, j = 0; i < len; i += 3, j += 4)
    {
        int s = (data[i] << 16) + (((i + 1) < len) ? (data[i + 1] << 8) : 0) + (((i + 2) < len) ? data[i + 2] : 0);

        encoded[j] = b64_table[(s >> 18) & 0x3F];
        encoded[j + 1] = b64_table[(s >> 12) & 0x3F];
        encoded[j + 2] = ((i + 1) < len) ? b64_table[(s >> 6) & 0x3F] : '=';
        encoded[j + 3] = ((i + 2) < len) ? b64_table[s & 0x3F] : '=';
    }
    encoded[j] = '\0';
}

static JSValue js_base64_encode(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    size_t len;
    const char *str = JS_ToCStringLen(ctx, &len, argv[0]);
    char *encoded = malloc((strlen(str) * 4) / 3);
    base64_encode(str, encoded);
    JS_FreeCString(ctx, str);
    JSValue js_string = JS_NewString(ctx, encoded);
    free(encoded);
    return js_string;
}

static JSValue js_block_index(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    return JS_NewBigInt64(ctx, block_index());
}

void js_add_global_function(const char *name, JSCFunction *func, int length)
{
    JS_SetPropertyStr(ctx, global_obj, name, JS_NewCFunction(ctx, func, name, length));
}

void create_runtime()
{
    if (rt != NULL)
    {
        return;
    }
    rt = JS_NewRuntime();
    ctx = JS_NewContextRaw(rt);
    JS_AddIntrinsicBaseObjects(ctx);
    JS_AddIntrinsicDate(ctx);
    JS_AddIntrinsicEval(ctx);
    JS_AddIntrinsicStringNormalize(ctx);
    JS_AddIntrinsicRegExp(ctx);
    JS_AddIntrinsicJSON(ctx);
    JS_AddIntrinsicProxy(ctx);
    JS_AddIntrinsicMapSet(ctx);
    JS_AddIntrinsicTypedArrays(ctx);
    JS_AddIntrinsicBigInt(ctx);

    global_obj = JS_GetGlobalObject(ctx);
    js_add_global_function("block_index", &js_block_index, 0);
    js_add_global_function("base64_encode", &js_base64_encode, 1);
}

JSValue js_eval(const char *source)
{
    create_runtime();
    int len = strlen(source);
    JSValue val = JS_Eval(ctx,
                          source,
                          len,
                          "",
                          JS_EVAL_TYPE_GLOBAL);
    return val;
}

void store_js()
{
    input(0);
    const char *scriptbuffer = malloc(register_len(0));
    read_register(0, (int64_t)scriptbuffer);
    storage_write(STORAGE_KEY_LEN, (int64_t)STORAGE_KEY, register_len(0), (int64_t)scriptbuffer, 0);
}

void web4_get()
{
    storage_read(STORAGE_KEY_LEN, (int64_t)STORAGE_KEY, 0);
    const char *scriptbuffer = malloc(register_len(0));
    read_register(0, (int64_t)scriptbuffer);
    JSValue result = js_eval(scriptbuffer);
    JSValue stringified_result = JS_JSONStringify(ctx, result, JS_NULL, JS_NewInt32(ctx, 1));
    const char *result_string = JS_ToCString(ctx, stringified_result);
    value_return(strlen(result_string), (int64_t)result_string);
}
