const SAMPLE_BUFFER_START = 1024;

const samplebuffer = changetype<StaticArray<f32>>(SAMPLE_BUFFER_START);
// store the byte length of the array
store<i32>(SAMPLE_BUFFER_START - sizeof<i32>(), 128 * 4);

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
