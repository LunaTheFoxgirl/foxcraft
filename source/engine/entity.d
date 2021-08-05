module engine.entity;
import engine;
import engine.render;

/**
    An entity
*/
class Entity {
protected:
    World world;

public:
    /**
        Position of the entity in the world
    */
    vec3 position = vec3(0, 256, 0);

    /**
        Basic constructor
    */
    this(World world) {
        this.world = world;
    }

    /**
        Position in the world
    */
    final vec3 worldPosition() {
        return vec3(position.x, -position.y, position.z);
    }

    /**
        Updates the entity
    */
    abstract void update();
}