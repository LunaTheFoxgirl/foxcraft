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
    vec3 position = vec3(0, -256, 0);

    this(World world) {
        this.world = world;
    }

    /**
        Updates the entity
    */
    abstract void update();
}