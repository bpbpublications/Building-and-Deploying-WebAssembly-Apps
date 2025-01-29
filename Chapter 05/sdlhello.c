#include <SDL.h>

SDL_Window *window;
SDL_Renderer *renderer;

int main(int argc, char *argv[])
{
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow("SDL Rectangle",
                              SDL_WINDOWPOS_CENTERED,
                              SDL_WINDOWPOS_CENTERED,
                              640, 480,
                              SDL_WINDOW_SHOWN);

    // Create a renderer
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);

    SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);

    // Draw a rectangle
    SDL_Rect rect = {220, 140, 200, 200};
    SDL_RenderFillRect(renderer, &rect);
    SDL_RenderPresent(renderer);

    return 0;
}
