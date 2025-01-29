global.bpm = 120;
global.pattern_size_shift = 4;

// Instruments

addInstrument('kick', {
    type: 'number', sointu: {
        "numvoices": 1,
        "units": [
            { type: "envelope", id: 'env', parameters: { attack: 5, decay: 64, gain: 100, release: 64, stereo: 0, sustain: 0 } },
            { type: 'send', parameters: { amount: 128, port: 4, sendpop: 0, stereo: 0, target: 'env' } },
            { type: "envelope", parameters: { attack: 0, decay: 70, gain: 115, release: 0, stereo: 0, sustain: 0 } },
            { type: 'distort', parameters: { drive: 32, stereo: 0 } },
            { type: 'send', parameters: { amount: 128, port: 1, sendpop: 0, stereo: 0, target: 'osc' } },
            { type: 'pop', parameters: { stereo: 0 } },
            { type: 'oscillator', id: 'osc', parameters: { color: 64, detune: 55, gain: 45, lfo: 0, phase: 0, shape: 96, stereo: 0, transpose: 46, type: 1, unison: 1 } },
            { type: 'mulp', parameters: { stereo: 0 } },
            { type: 'filter', parameters: { lowpass: 1, frequency: 30, resonance: 128 } },
            { type: 'loadnote', parameters: { stereo: 0 } },
            { type: 'mulp', parameters: { stereo: 0 } },
            { type: 'pan', parameters: { panning: 64, stereo: 0 } },
            { type: 'outaux', parameters: { outgain: 102, auxgain: 18, stereo: 1 } },
            { type: "loadnote" }, { type: "envelope", parameters: { attack: 0, gain: 128, stereo: 0, decay: 80, sustain: 0, release: 80 } },
            { type: "mulp" },
            { type: "sync", parameters: {} },
            { type: "pop", parameters: {} }
        ]
    }
});

addInstrument('hihat', {
    type: 'number', sointu: {
        "numvoices": 1,
        "units": [
            { type: "envelope", parameters: { attack: 0, decay: 64, gain: 76, release: 32, stereo: 0, sustain: 15 } },
            { type: "noise", parameters: { gain: 128, shape: 64, stereo: 0 } },
            { type: 'mulp', parameters: { stereo: 0 } },
            { type: 'filter', parameters: { bandpass: 1, frequency: 128, highpass: 0, lowpass: 0, negbandpass: 0, neghighpass: 0, resonance: 128, stereo: 0 } },
            { type: 'loadnote', parameters: { stereo: 0 } },
            { type: 'mulp', parameters: { stereo: 0 } },
            { type: 'pan', parameters: { panning: 64, stereo: 0 } },
            { type: 'outaux', parameters: { outgain: 100, auxgain: 100, stereo: 1 } },
            { type: "loadnote" }, { type: "envelope", parameters: { attack: 0, gain: 128, stereo: 0, decay: 80, sustain: 0, release: 80 } }, { type: "mulp" }, { type: "sync", parameters: {} }, { type: "pop", parameters: {} }
        ]
    }
});

const bass = {
    type: 'note', sointu: {
        "numvoices": 1,
        "units": [
            { type: "envelope", id: 'env', parameters: { attack: 32, decay: 76, gain: 55, release: 75, stereo: 0, sustain: 28 } },
            { type: 'oscillator', parameters: { color: 90, detune: 64, gain: 128, lfo: 0, phase: 32, shape: 96, stereo: 0, transpose: 76, type: 2, unison: 0 } },
            { type: 'mulp', parameters: { stereo: 0 } },
            { type: 'filter', parameters: { lowpass: 1, frequency: 20, resonance: 128 } },
            { type: 'pan', parameters: { panning: 64, stereo: 0 } },
            { type: 'outaux', parameters: { outgain: 100, auxgain: 10, stereo: 1 } },
            { type: "loadnote" },
            { type: "envelope", parameters: { attack: 0, gain: 128, stereo: 0, decay: 80, sustain: 0, release: 80 } },
            { type: "mulp" }, { type: "sync", parameters: {} },
            { type: "pop", parameters: {} }
        ]
    }
};
addInstrument('bass_1', bass);
addInstrument('bass_2', bass);
addInstrumentGroup('bass', ['bass_1', 'bass_2']);

addInstrument('Global', {
    type: 'number', sointu: {

        "numvoices": 1,
        "units": [
            { type: 'in', parameters: { channel: 2, stereo: 1 } },
            { type: 'delay', parameters: { damp: 64, dry: 128, feedback: 125, notetracking: 0, pregain: 30, stereo: 0 }, varargs: [1116, 1188, 1276, 1356, 1422, 1492, 1556, 1618] },
            { type: 'outaux', parameters: { auxgain: 0, outgain: 128, stereo: 1 } },
            { type: 'in', parameters: { channel: 4, stereo: 1 } },
            { type: 'delay', parameters: { damp: 64, dry: 64, feedback: 64, notetracking: 0, pregain: 53, stereo: 0 }, varargs: [16537, 16537] },
            { type: 'outaux', parameters: { auxgain: 0, outgain: 128, stereo: 1 } },
            { type: 'in', parameters: { channel: 0, stereo: 1 } },
            { type: 'push', parameters: { channel: 0, stereo: 1 } },
            { type: 'filter', parameters: { bandpass: 0, frequency: 32, highpass: 1, lowpass: 0, negbandpass: 0, neghighpass: 0, resonance: 128, stereo: 1 } },
            { type: 'compressor', parameters: { attack: 16, invgain: 90, ratio: 20, release: 54, stereo: 1, threshold: 50 } },
            { type: 'mulp', parameters: { stereo: 1 } },
            { type: 'xch', parameters: { stereo: 1 } },
            { type: 'filter', parameters: { bandpass: 0, frequency: 7, highpass: 1, lowpass: 0, negbandpass: 0, neghighpass: 0, resonance: 128, stereo: 1 } },
            { type: 'compressor', parameters: { attack: 8, invgain: 80, ratio: 10, release: 64, stereo: 1, threshold: 40 } },
            { type: 'mulp', parameters: { stereo: 1 } },
            { type: 'addp', parameters: { stereo: 1 } },
            { type: 'outaux', parameters: { auxgain: 0, outgain: 128, stereo: 1 } }
        ]
    }
});

// Sequence

playPatterns({
    bass: pp(4, [
        e2, , , e2,
        , [, e2], , d3,
        [, e3], , , a2,
        , , [, b2], ,
    ], 2),
    kick: pp(4, [
        70, 0, 0, 0,
        70, 0, 0, 0,
        70, 0, 0, 0,
        70, 0, 0, 0
    ]),
    hihat: pp(4, [
        0, 0, 60, 0,
        0, 0, 60, 0,
        0, 0, 60, 0,
        0, 0, 60, 70
    ])
}, 1);