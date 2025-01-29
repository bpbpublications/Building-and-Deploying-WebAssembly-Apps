#include "./quickjs-2024-01-13/quickjs.h"
#include <string.h>

extern void js_sleep(int duration, JSValue *resolving_functions);
extern void js_value_return(int result);

JSValue global_obj;
JSRuntime *rt = NULL;
JSContext *ctx;

void js_std_loop_no_os(JSContext *ctx)
{
    JSContext *ctx1;
    int err;

    for (;;)
    {
        err = JS_ExecutePendingJob(JS_GetRuntime(ctx), &ctx1);
        if (err <= 0)
        {
            break;
        }
    }
}

void js_add_global_function(const char *name, JSCFunction *func, int length)
{
    JS_SetPropertyStr(ctx, global_obj, name, JS_NewCFunction(ctx, func, name, length));
}

JSValue value_return(JSContext *ctx, JSValueConst this_val,
              int argc, JSValueConst *argv)
{
    int i;
    const char *url;
    size_t len;
    JSValue promise, resolving_funcs[2];

    int result = JS_VALUE_GET_INT(argv[0]);

    js_value_return(result);
    return JS_NewInt32(ctx, 0);
}


JSValue sleep(JSContext *ctx, JSValueConst this_val,
              int argc, JSValueConst *argv)
{
    int i;
    const char *url;
    size_t len;
    JSValue promise, resolving_funcs[2];

    int duration = JS_VALUE_GET_INT(argv[0]);

    promise = JS_NewPromiseCapability(ctx, resolving_funcs);
    js_sleep(duration, resolving_funcs);
    return promise;
}

void sleep_callback(JSValue *resolving_functions, int result)
{
    JSValue argv[1] = {result};
    JS_Call(ctx, resolving_functions[0], JS_UNDEFINED, 1, argv);
    js_std_loop_no_os(ctx);
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
    JS_AddIntrinsicEval(ctx);
    JS_AddIntrinsicPromise(ctx);

    global_obj = JS_GetGlobalObject(ctx);
    js_add_global_function("sleep", sleep, 1);
    js_add_global_function("value_return", value_return, 1);
}

JSValue js_eval_async_module(const char *source)
{
    create_runtime();
    int len = strlen(source);
    JSValue val = JS_Eval(ctx,
                          source,
                          len,
                          "",
                          JS_EVAL_TYPE_MODULE);
    js_std_loop_no_os(ctx);
    return val;
}
