#include "./instruments.h"

typedef struct w2c_environment
{
    f32 SAMPLERATE;
} w2c_environment;

w2c_instruments instance;
w2c_environment environment;

f32 *w2c_environment_SAMPLERATE(struct w2c_environment *environment)
{
    return &environment->SAMPLERATE;
}

void instrlib_init(f32 samplerate)
{
    wasm_rt_init();
    environment.SAMPLERATE = samplerate;
    wasm2c_instruments_instantiate(&instance, &environment);
}

void instrlib_fillsamplebufferwithnumsamples(int num_samples) {
    w2c_instruments_fillSampleBufferWithNumSamples(&instance, num_samples);
}

f32 *instrlib_getSampleBuffer()
{
    wasm_rt_memory_t *memory = w2c_instruments_memory(&instance);
    u32 *samplebufferaddr = w2c_instruments_samplebuffer(&instance);
    return (f32 *)(memory->data + *samplebufferaddr);
}

void instrlib_shortMessage(u32 d0, u32 d1, u32 d2)
{
    w2c_instruments_shortmessage(&instance, d0, d1, d2);
}
