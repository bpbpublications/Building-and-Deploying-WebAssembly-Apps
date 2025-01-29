#include <stdio.h>
#include <stdlib.h>
#include <AL/al.h>
#include <AL/alc.h>
#include <xmp.h>

#define BUFFER_SIZE 4096
#define NUM_BUFFERS 4
#define SAMPLERATE 44100

int main(int argc, char **argv) {
    xmp_context context;
    struct xmp_frame_info frame_info;
    ALuint source, buffers[NUM_BUFFERS];
    ALCdevice *device;
    ALCcontext *alcContext;
    short buffer[BUFFER_SIZE];
    int ret, state;

    // Check command-line arguments
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <modfile>\n", argv[0]);
        return EXIT_FAILURE;
    }

    // Initialize OpenAL
    device = alcOpenDevice(NULL); // Open default device
    if (!device) {
        fprintf(stderr, "Failed to open OpenAL device\n");
        return EXIT_FAILURE;
    }

    alcContext = alcCreateContext(device, NULL);
    alcMakeContextCurrent(alcContext);

    // Generate OpenAL buffers and source
    alGenBuffers(2, buffers);
    alGenSources(1, &source);

    // Create a new libxmp context
    context = xmp_create_context();
    if (context == NULL) {
        fprintf(stderr, "Failed to create libxmp context\n");
        return EXIT_FAILURE;
    }

    // Load module
    ret = xmp_load_module(context, argv[1]);
    if (ret < 0) {
        fprintf(stderr, "Failed to load module: %s\n", argv[1]);
        xmp_free_context(context);
        return EXIT_FAILURE;
    }

    // Start playing with libxmp
    ret = xmp_start_player(context, SAMPLERATE, 0);
    if (ret < 0) {
        fprintf(stderr, "Failed to start player\n");
        xmp_release_module(context);
        xmp_free_context(context);
        return EXIT_FAILURE;
    }

    // Initial buffer filling
    for (int i = 0; i < NUM_BUFFERS; i++) {
        xmp_play_buffer(context, buffer, BUFFER_SIZE, 0);
        alBufferData(buffers[i], AL_FORMAT_STEREO16, buffer, BUFFER_SIZE, SAMPLERATE);
        alSourceQueueBuffers(source, 1, &buffers[i]);
    }

    alSourcePlay(source);

    // Main loop
    while (1) {
        alGetSourcei(source, AL_SOURCE_STATE, &state);
        if (state == AL_STOPPED)
            break;

        int processed;
        alGetSourcei(source, AL_BUFFERS_PROCESSED, &processed);

        while (processed--) {
            ALuint bufid;
            alSourceUnqueueBuffers(source, 1, &bufid);

            xmp_play_buffer(context, buffer, BUFFER_SIZE, 0);
            alBufferData(bufid, AL_FORMAT_STEREO16, buffer, BUFFER_SIZE, SAMPLERATE);
            alSourceQueueBuffers(source, 1, &bufid);
        }

        if (state != AL_PLAYING) {
            alSourcePlay(source);
        }

        emscripten_sleep(10);
    }

    printf("stopped\n");
    // Cleanup
    xmp_end_player(context);
    xmp_release_module(context);
    xmp_free_context(context);

    alDeleteSources(1, &source);
    alDeleteBuffers(2, buffers);
    alcMakeContextCurrent(NULL);
    alcDestroyContext(alcContext);
    alcCloseDevice(device);

    return EXIT_SUCCESS;
}
