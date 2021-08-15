module engine;
import bindbc.opengl;
import bindbc.sdl;
import engine.render;
import game;

public import engine.entity;
public import engine.camera;
public import engine.world;
public import engine.block;
public import engine.chunk;
public import engine.chunk.mesh;
public import engine.chunk.meshgen;
public import engine.input;
public import engine.math;

import std.stdio : writeln;

private {
    bool closeRequested;
    long lastFrameTime = 0;
    long nowFrameTime = 0;
    double deltaTime = 0;

    vec2i viewport;
}

vec3 moveVector = vec3(0);

/**
    Initializes the engine
*/
void fcInitEngine() {
    loadSDL();
    SDL_Init(SDL_INIT_EVERYTHING);

    // Create Window and OpenGL context
    fcGameWindowCreate("FoxCraft");

    // Initialize game systems
    fcInitAtlas();
    fcInitChunkMeshRender();
    fcInitBlockSelect();

    // Initialize game resources
    fcInitBlocks();
}

/**
    Starts the engine
*/
void fcStartEngine() {

    TheWorld = new World(0);

    MeshGenerator.start();
    ChunkProvider.start();
    ChunkProvider.preload();

    // Initialize viewport
    uint vx, vy;
    fcGameWindowSize(vx, vy);
    viewport = vec2i(vx, vy);
    glViewport(0, 0, viewport.x, viewport.y);

    // Game Loop
    SDL_Event event;
    while(!closeRequested) {
        
        lastFrameTime = nowFrameTime;
        nowFrameTime = SDL_GetPerformanceCounter();
        deltaTime = (nowFrameTime-lastFrameTime)*1000 / cast(double)SDL_GetPerformanceFrequency();
        fcInputFlush();

        // Update event loop
        SDL_PumpEvents();
        while (fcGameWindowPollEvent(&event)) {           
            
            // Update window & input
            fcGameWindowUpdate(event);
            fcInputUpdate(event);

            // Update other events
            switch(event.type) {
                case SDL_QUIT:
                    closeRequested = true;
                    break;

                case SDL_WINDOWEVENT: 
                    switch(event.window.event) {
                        case SDL_WINDOWEVENT_SIZE_CHANGED:
                            viewport = vec2i(
                                event.window.data1,
                                event.window.data2
                            );
                            glViewport(0, 0, viewport.x, viewport.y);
                            break;

                        default: break;
                    }
                    break;

                // TODO: Add more events
                default: break;
            }
        }

        // Update the game and render
        if (FcCamera.worldPosition.y < 16) glClearColor(0, 0, 0, 1);
        else glClearColor(0.45, 0.45, 0.85, 1);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

        MeshGenerator.update();
        TheWorld.update();

        // End loop
        fcGameWindowSwap();

        import core.memory : GC;
        import std.format : format;
        auto stats = GC.stats;
        fcGameWindowSetTitle(
            "FoxCraft - %smb used, %smb free, %smb total (main thread), %s chunks loaded ー %sms delta".format(
                stats.usedSize/1_000_000, 
                stats.freeSize/1_000_000, 
                (stats.freeSize+stats.usedSize)/1_000_000,
                TheWorld.chunks.length,
                cast(int)fcDeltaTime()
            )
        );

        // Apparently the GC doesn't collect itself
        GC.collect();
    }

    MeshGenerator.stop();
}

/**
    Gets the current viewport width and height
*/
vec2i fcViewport() {
    return viewport;
}

/**
    Total game time
*/
double fcTotalTime() {
    return cast(double)nowFrameTime;
}

/**
    Delta time
*/
double fcDeltaTime() {
    return deltaTime;
}