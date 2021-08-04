module engine.input;
import bindbc.sdl;
import gl3n.linalg;

public import engine.input.keyboard;

private {
    float mouseRelX;
    float mouseRelY;
}

package(engine) {
    /**
        Updates input
    */
    void fcInputUpdate(SDL_Event event) {

        switch(event.type) {
            case SDL_MOUSEMOTION:
                mouseRelX = event.motion.xrel;
                mouseRelY = event.motion.yrel;
                break;
            default: break;
        }
    }

    void fcInputFlush() {
        mouseRelX = 0;
        mouseRelY = 0;
    }
}

/**
    Returns the relative amount the mouse has moved since the last frame
*/
vec2 fcMouseMotion() {
    return vec2(mouseRelX, mouseRelY);
}