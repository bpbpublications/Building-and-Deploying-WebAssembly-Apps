#include <emscripten.h>
#include <cmath>
#include <ctime>

// Global variables for the RGB components
float r = 0, g = 0, b = 0;

// Function to update the RGB values based on sine wave
void updateColors() {
    // Current time in seconds
    float time = static_cast<float>(clock()) / CLOCKS_PER_SEC;

    // Sine wave parameters: amplitude, frequency, and phase offset
    float amplitude = 127.5;
    float frequency = 1.0;
    
    // Update r, g, b values based on sine wave with different phase offsets
    r = amplitude * (sin(frequency * time) + 1.0); // No offset for red
    g = amplitude * (sin(frequency * time + 2.0944) + 1.0); // 120 degrees offset for green
    b = amplitude * (sin(frequency * time + 4.18879) + 1.0); // 240 degrees offset for blue
}

// Function to change the background color
void changeBackground() {
    EM_ASM({
        document.querySelector('body').style.backgroundColor = `rgb(${$0},${$1},${$2})`;
    }, static_cast<int>(r), static_cast<int>(g), static_cast<int>(b));
}

// Main loop function
void mainLoop() {
    updateColors();
    changeBackground();
}

int main() {
    // Set the main loop to run at 60 fps
    emscripten_set_main_loop(mainLoop, 60, 1);

    return 0;
}
