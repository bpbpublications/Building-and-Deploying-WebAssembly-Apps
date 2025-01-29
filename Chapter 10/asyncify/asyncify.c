#include "emscripten.h"
#include <stdio.h>

EM_ASYNC_JS(int, timeout, (int duration), {
  return await js_timeout(duration);
});

EMSCRIPTEN_KEEPALIVE
void wasm_sleep(int duration) {
    printf("Before sleep %d\n",12345);
    int result = timeout(duration);
    printf("After sleep %d\n", result);
}
