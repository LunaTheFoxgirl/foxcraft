module engine.camera;
import engine;
import engine.world;
import engine.render;

/**
    The game's camera
*/
__gshared Camera FcCamera;

/**
    A camera
*/
class Camera {
    
    /**
        Position of camera
    */
    vec3 position = vec3(0, 0, 0);

    /**
        Rotation of camera
    */
    vec3 rotation = vec3(0);

    /**
        Position in the world
    */
    vec3 worldPosition() {
        return vec3(position.x, -position.y, position.z);
    }

    mat4 getMatrix() {
        vec2i viewport = fcViewport();
        return 
            mat4.perspective(viewport.x, viewport.y, 90, 0.1, 1000) *
            this.getRotationMatrix() * 
            mat4.translation(position.x, position.y, position.z);
    }

    mat4 getRotationMatrix() {
        return
            mat4.xrotation(rotation.x) *
            mat4.yrotation(rotation.y) ;
    }
}

static this() {
    FcCamera = new Camera();
}