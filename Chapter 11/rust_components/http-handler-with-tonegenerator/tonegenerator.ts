const SAMPLERATE: f32 = 44100;
let step: f32;
let position: f32 = 0;

export function setnote(note: f32): void {
    const frequency = (440.0 as f32) * Mathf.pow(2, (-69 + note) / 12);
    step = frequency / SAMPLERATE;
}

export function nextsample(): f32 {
    position += step;
    return Mathf.sin(position * Mathf.PI * 2.0);
}
