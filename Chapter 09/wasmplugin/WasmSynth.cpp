#include <JuceHeader.h>

extern "C" void instrlib_init(float samplerate);
extern "C" void instrlib_fillsamplebufferwithnumsamples(int numsamples);
extern "C" float *instrlib_getSampleBuffer();
extern "C" void instrlib_shortMessage(uint32_t d0, uint32_t d1, uint32_t d2);

class WasmSynth final : public AudioProcessor
{
public:
    WasmSynth()
        : AudioProcessor(BusesProperties().withOutput("Output", AudioChannelSet::stereo()))
    {
    }

    static String getIdentifier()
    {
        return "Wasm Synth";
    }

    void prepareToPlay(double newSampleRate, int) override
    {
        synth.setCurrentPlaybackSampleRate(newSampleRate);
        printf("Samplerate is %f\n", newSampleRate);
        instrlib_init((float)newSampleRate);
        printf("Prepare complete");
    }

    void releaseResources() override {}

    void processBlock(AudioBuffer<float> &buffer, MidiBuffer &midiMessages) override
    {
        for (const auto metadata : midiMessages)
        {
            MidiMessage message = metadata.getMessage();
            const uint8 *rawmessage = message.getRawData();
            printf("%d, %d, %d\n", rawmessage[0], rawmessage[1], rawmessage[2]);
            instrlib_shortMessage(rawmessage[0], rawmessage[1], rawmessage[2]);
        }

        int numSamples = buffer.getNumSamples();
        auto *left = buffer.getWritePointer(0);
        auto *right = buffer.getWritePointer(1);

        for (int sampleNo = 0; sampleNo < numSamples; sampleNo += 128)
        {
            int numSamplesToRender = numSamples - sampleNo;
            if (numSamplesToRender > 128) {
                numSamplesToRender = 128;
            }
            instrlib_fillsamplebufferwithnumsamples(numSamplesToRender);
            float *renderbuf = instrlib_getSampleBuffer();
            for (int ndx = 0; ndx < numSamplesToRender; ndx++)
            {
                left[sampleNo + ndx] = renderbuf[ndx] * 0.3;
                right[sampleNo + ndx] = renderbuf[ndx + 128] * 0.3;
            }
        }
    }

    using AudioProcessor::processBlock;

    const String getName() const override { return getIdentifier(); }
    double getTailLengthSeconds() const override { return 0.0; }
    bool acceptsMidi() const override { return true; }
    bool producesMidi() const override { return true; }
    AudioProcessorEditor *createEditor() override { return nullptr; }
    bool hasEditor() const override { return false; }
    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const String getProgramName(int) override { return {}; }
    void changeProgramName(int, const String &) override {}
    void getStateInformation(juce::MemoryBlock &) override {}
    void setStateInformation(const void *, int) override {}

private:
    Synthesiser synth;
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WasmSynth)
};

juce::AudioProcessor *JUCE_CALLTYPE createPluginFilter()
{
    return new WasmSynth();
}
