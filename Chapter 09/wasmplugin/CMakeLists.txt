cmake_minimum_required(VERSION 3.15)

project(WasmSynth VERSION 0.0.1)

add_subdirectory(JUCE-7.0.9)

juce_add_plugin(WasmSynth
    COMPANY_NAME "WebAssemblyMusic"
    IS_SYNTH TRUE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE WaMu
    PLUGIN_CODE Wasm
    FORMATS VST3 AU Standalone)

target_sources(WasmSynth
    PRIVATE
        wasmsynth.cpp)

target_compile_definitions(WasmSynth
    PRIVATE
        JUCE_VST3_CAN_REPLACE_VST2=0)

target_link_libraries(WasmSynth
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/libinstrlib.a
        juce::juce_audio_utils
    PUBLIC
        juce::juce_audio_plugin_client
        juce::juce_dsp)

juce_generate_juce_header(WasmSynth)
