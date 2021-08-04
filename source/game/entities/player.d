module game.entities.player;
import engine.camera;
import engine.render;
import engine;
import std.stdio : writeln;

/**
    The player
*/
class PlayerEntity : Entity {
    KeyboardState* lstate;
    KeyboardState* kstate;

    BlockRef placeId = 0;

    /**
        Constructs the player
    */
    this(World world) {
        super(world);
    }

    override
    void update() {
        enum MoveSpeed = 0.25;
        lstate = kstate;
        kstate = fcKeyboardGetState();
        vec2 mMotion = fcMouseMotion();

        if (fcGameGetRelativeMouse()) {
            FcCamera.rotation.x += radians(mMotion.y)*0.8;
            FcCamera.rotation.y += radians(mMotion.x)*0.8;
            FcCamera.rotation.x = clamp(FcCamera.rotation.x, -radians(90), radians(90));
            
            vec3 rightVector = vec4(MoveSpeed, 0, 0, 1) * FcCamera.getRotationMatrix();
            vec3 upVector = vec4(0, MoveSpeed, 0, 1);
            vec3 forwardVector = vec4(0, 0, MoveSpeed, 1) * FcCamera.getRotationMatrix();

            if (kstate.isKeyDown(Keys.W)) position += forwardVector;
            if (kstate.isKeyDown(Keys.S)) position -= forwardVector;
            if (kstate.isKeyDown(Keys.D)) position -= rightVector;
            if (kstate.isKeyDown(Keys.A)) position += rightVector;
            if (kstate.isKeyDown(Keys.LeftShift)) position += upVector;
            if (kstate.isKeyDown(Keys.Space)) position -= upVector;
        }

        FcCamera.position = vec3(position.x, position.y - 1, position.z);

        if (lstate !is null) {

            if (kstate.isKeyDown(Keys.E) && lstate.isKeyUp(Keys.E)) {
                vec3 forwardVector = vec4(0, 0, 0.8, 1) * FcCamera.getRotationMatrix();
                vec3 ray = FcCamera.position;
                vec3 lastRay;
                foreach(i; 0..8) {
                    lastRay = ray;
                    ray += forwardVector;
                    auto rayBlock = WorldPos(vec3i(cast(int)floor(ray.x), cast(int)floor(abs(ray.y)), cast(int)floor(ray.z)));
                    auto lastRayBlock = WorldPos(vec3i(cast(int)floor(lastRay.x), cast(int)floor(abs(lastRay.y)), cast(int)floor(lastRay.z)));
                    writeln(rayBlock);

                    Chunk chunk = world.getChunkAt(rayBlock);
                    if (chunk !is null) {
                        if (chunk.hasBlockAt(rayBlock)) {
                            if (placeId == 0) {
                                chunk.setBlockAt(rayBlock, 0);
                            } else {
                                chunk.setBlockAt(lastRayBlock, placeId);
                            }
                            return;
                        }
                    }
                }
                writeln("Hit nothing");
            }

            if (kstate.isKeyDown(Keys.One) && lstate.isKeyUp(Keys.One)) {
                placeId = 0;
            }

            if (kstate.isKeyDown(Keys.Two) && lstate.isKeyUp(Keys.Two)) {
                placeId = 1;
            }

            if (kstate.isKeyDown(Keys.Three) && lstate.isKeyUp(Keys.Three)) {
                placeId = 2;
            }

            if (kstate.isKeyDown(Keys.Escape) && lstate.isKeyUp(Keys.Escape)) {
                fcGameSetRelativeMouse(!fcGameGetRelativeMouse);
            }
        }

    }
}