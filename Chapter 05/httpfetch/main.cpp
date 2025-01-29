#include <emscripten.h>
#include <iostream>

EM_ASYNC_JS(const char*, fetch_example, (), {
    const data = await fetch('http://jsonplaceholder.typicode.com/posts/1').then(response => response.text());
    const lengthBytes = lengthBytesUTF8(data) + 1;
    const stringOnWasmHeap = _malloc(lengthBytes);
    stringToUTF8(data, stringOnWasmHeap, lengthBytes);
    return stringOnWasmHeap;
});

int main() {
    const char* data = fetch_example();
    std::cout << data << std::endl;
    return 0;
}
