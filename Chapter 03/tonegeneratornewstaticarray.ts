export const samplebuffer = new StaticArray<f32>(128);

const SAMPLERATE: f32 = 44100;
let _step: f32;
let _val: f32 = 0;

export function setFrequency(frequency: f32): void {
    _step = frequency / SAMPLERATE;
}

export function fillSampleBuffer(): void {
    for (let n = 0; n < samplebuffer.length; n++) {
        _val += _step;
        _val %= 1.0;
        samplebuffer[n] = _val - 0.5;
    }
}
