#include <stdio.h>

#ifndef WAVHEADER_H_
#define WAVHEADER_H_

void writeWavHeader(FILE *fp, int sampleRate, int numChannels, int bitsPerSample, int numSamples) {
    int byteRate = sampleRate * numChannels * bitsPerSample / 8;
    int blockAlign = numChannels * bitsPerSample / 8;

    fwrite("RIFF", sizeof(char), 4, fp);
    int chunkSize = 36 + numSamples * numChannels * bitsPerSample / 8;
    fwrite(&chunkSize, sizeof(int), 1, fp);
    fwrite("WAVE", sizeof(char), 4, fp);

    fwrite("fmt ", sizeof(char), 4, fp);
    int subChunk1Size = 16;
    fwrite(&subChunk1Size, sizeof(int), 1, fp);
    short audioFormat = 3;
    fwrite(&audioFormat, sizeof(short), 1, fp);
    fwrite(&numChannels, sizeof(short), 1, fp);
    fwrite(&sampleRate, sizeof(int), 1, fp);
    fwrite(&byteRate, sizeof(int), 1, fp);
    fwrite(&blockAlign, sizeof(short), 1, fp);
    fwrite(&bitsPerSample, sizeof(short), 1, fp);

    fwrite("data", sizeof(char), 4, fp);
    int subChunk2Size = numSamples * numChannels * bitsPerSample / 8;
    fwrite(&subChunk2Size, sizeof(int), 1, fp);
}

#endif  /* WAVHEADER_H_ */