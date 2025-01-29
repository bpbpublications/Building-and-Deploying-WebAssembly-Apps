#include "./tonegenerator.h"
#include "./wavheader.h"
#include <stdio.h>

w2c_tonegenerator tonegenerator;

int main()
{
    wasm_rt_init();
    wasm2c_tonegenerator_instantiate(&tonegenerator);

    int CHUNK_FRAMES = 128;
    int SAMPLERATE = 44100;
    int DURATION_SECONDS = 10;

    FILE *fptr;
    fptr = fopen("test.wav", "w");

    writeWavHeader(fptr, SAMPLERATE, 2, 32, DURATION_SECONDS * SAMPLERATE * 2);

    wasm_rt_memory_t *memory = w2c_tonegenerator_memory(&tonegenerator);
    u32 *samplebufferaddr = w2c_tonegenerator_samplebuffer(&tonegenerator);
    f32 *samplebuffer = (f32*)(memory->data + *samplebufferaddr);

    f32 frequency = 30.0;

    for (int chunkNo = 0; chunkNo < (DURATION_SECONDS * SAMPLERATE / CHUNK_FRAMES); chunkNo++)
    {
        w2c_tonegenerator_fillSampleBuffer(&tonegenerator);

        w2c_tonegenerator_setFrequency(&tonegenerator, frequency);
        for (int ndx = 0; ndx < CHUNK_FRAMES; ndx++)
        {
            float left = samplebuffer[ndx];
            float right = samplebuffer[ndx + 128];
            fwrite(&left, 1, sizeof(left), fptr);
            fwrite(&right, 1, sizeof(right), fptr);
        }

        frequency+=0.02;
    }

    fclose(fptr);
}