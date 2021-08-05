module engine.render.window;
import bindbc.sdl;
import std.string;
import engine.render.gl;

/**
    The Game Window
*/
private __gshared SDL_Window* fcGameWindow;
private int width, height;

/**
    Gets the window pointer
*/
SDL_Window* fcGetWindowPtr() {
    return fcGameWindow;
}

extern(Windows) void debugMessage(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar *message, const void *userParam) nothrow {
    (cast(void delegate() nothrow)() {
        import std.stdio : writefln;
        string severity;
        switch(type) {
            case GL_DEBUG_TYPE_ERROR: severity = "ERROR"; break;
            case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: severity = "DEPRC"; break;
            case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR: severity = "UNDEF"; break;
            case GL_DEBUG_TYPE_PORTABILITY: severity = "PORTA"; break;
            case GL_DEBUG_TYPE_PERFORMANCE: severity = "PERFC"; break;
            case GL_DEBUG_TYPE_MARKER: severity = "MARKR"; break;
            case GL_DEBUG_TYPE_PUSH_GROUP: severity = "PSGRP"; break;
            case GL_DEBUG_TYPE_POP_GROUP: severity = "PPGRP"; break;
            default: severity = "OTHER";
        }

        //writefln("[%s]: %s", severity, cast(string)message.fromStringz);
    })();
}

/**
    Creates a new game window
*/
void fcGameWindowCreate(string title) {
    // TODO: load last window size from file

    //SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);

    // Set buffer sizes and allow double buffering
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);

    // Create the Window
    fcGameWindow = SDL_CreateWindow(
        title.toStringz,
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        640,
        480,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE
    );

    width = 640;
    height = 480;

    // Makes the window's GL context current
    SDL_GL_MakeCurrent(
        fcGameWindow,
        SDL_GL_CreateContext(fcGameWindow)
    );

    // Sets VSync On
    SDL_GL_SetSwapInterval(1);
    

    // Loads OpenGL functions
    fcLoadGL();

    // glEnable(GL_DEBUG_OUTPUT);
    // glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
    // glDebugMessageCallback(&debugMessage, null);

    // glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, GL_TRUE);
    
}

/**
    Updates window based on SDL events
*/
void fcGameWindowUpdate(SDL_Event event) {
    if (event.type == SDL_WINDOWEVENT || cast(SDL_WindowEventID)event.window.type == SDL_WINDOWEVENT_RESIZED) {
        width = event.window.data1;
        height = event.window.data2;
    }
}

/**
    Sets the title of the Game Window
*/
void fcGameWindowSetTitle(string title) {
    SDL_SetWindowTitle(fcGameWindow, title.toStringz);
}

/**
    Polls an SDL event from the Window
*/
bool fcGameWindowPollEvent(SDL_Event* ev) {
    return cast(bool)SDL_PollEvent(ev);
}

/**
    Swap buffers
*/
void fcGameWindowSwap() {
    SDL_GL_SwapWindow(fcGameWindow);
}

/**
    Returns the size of the window
*/
void fcGameWindowSize(ref uint owidth, ref uint oheight) {
    owidth = width;
    oheight = height;
}

/**
    Sets relative mouse mode
*/
void fcGameSetRelativeMouse(bool mode) {
    SDL_SetRelativeMouseMode(cast(SDL_bool)mode);
}

/**
    Gets relative mouse mode
*/
bool fcGameGetRelativeMouse() {
    return cast(bool)SDL_GetRelativeMouseMode();
}