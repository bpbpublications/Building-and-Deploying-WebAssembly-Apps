#include "./instruments.h"
//#include <stdio.h>

typedef struct w2c_environment {
    f32 SAMPLERATE;
} w2c_environment;

w2c_instruments instance;
w2c_environment environment;

f32* w2c_environment_SAMPLERATE(struct w2c_environment* environment) {
    return &environment->SAMPLERATE;
}

void instrlib_init() {
    wasm_rt_init();
    environment.SAMPLERATE = 44100.0;

    wasm2c_instruments_instantiate(&instance, &environment);
}

void instrlib_fillsamplebuffer() {
    w2c_instruments_fillSampleBuffer(&instance);
}

void instrlib_playEventsAndFillSampleBuffer() {
    w2c_instruments_playEventsAndFillSampleBuffer(&instance);
}

f32 * instrlib_getSampleBuffer() {
    wasm_rt_memory_t* memory = w2c_instruments_memory(&instance);
    u32 * samplebufferaddr = w2c_instruments_samplebuffer(&instance);
    return memory->data + *samplebufferaddr;
}

void instrlib_shortMessage(u32 d0, u32 d1, u32 d2) {
    w2c_instruments_shortmessage(&instance, d0, d1, d2);
}

/*int main() {
    instrlib_init();
    for (int a = 0;a<1;a++) {
        instrlib_playEventsAndFillSampleBuffer();
        float * renderbuf = instrlib_getSampleBuffer();
        for (int n=0;n<128;n++) {
            printf("%.10e\n", renderbuf[n]);
        }
    }
}*/