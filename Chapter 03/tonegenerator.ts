const SAMPLE_BUFFER_START = 1024;
const SAMPLE_BUFFER_END = 1024 + 128 * 4;

const SAMPLERATE: f32 = 44100;
let _step: f32;
let _val: f32 = 0;

export function setFrequency(frequency: f32): void {
    _step = frequency / SAMPLERATE;
}

export function fillSampleBuffer(): void {
    for (let n=SAMPLE_BUFFER_START;n<SAMPLE_BUFFER_END;n+=4) {
        _val += _step;
        _val %= 1.0;
        store<f32>(n, _val - 0.5);
    }
}
