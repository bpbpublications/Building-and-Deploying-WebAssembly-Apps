class ToneGeneratorProcessor extends AudioWorkletProcessor {
  constructor() {
    super();

    this.port.onmessage = async (message) => {
      if (message.data.wasmbinary) {
        this.wasmmodule = await WebAssembly.instantiate(message.data.wasmbinary, {});

      }
      if (this.wasmmodule && message.data.frequency) {
        this.wasmmodule.instance.exports.setFrequency(message.data.frequency);
      }
    }
  }

  process(inputs, outputs, parameters) {
    if (this.wasmmodule) {
      this.wasmmodule.instance.exports.fillSampleBuffer();
      const output = outputs[0];

      output[0].set(new Float32Array(this.wasmmodule.instance.exports.memory.buffer, 1024, 128));
    }
    return true;
  }
}

registerProcessor("tone-generator-processor", ToneGeneratorProcessor);
