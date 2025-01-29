declare function sin(angle: f32): f32;
declare const PI: f32;

const SAMPLE_BUFFER_START = 1024;
const SAMPLE_BUFFER_END = 1024 + 128 * 4;

const SAMPLERATE: f32 = 44100;
const step: f32 = 440 / SAMPLERATE;
let angle: f32 = 0;

export function fillSampleBuffer(): void {
    for (let n=SAMPLE_BUFFER_START;n<SAMPLE_BUFFER_END;n+=4) {
        angle += step;
        const samplevalue = sin(angle * PI * 2);
        store<f32>(n, samplevalue);
    }
}