module game.entities.player;
import engine.camera;
import engine.render;
import engine;
import std.stdio : writeln;

/**
    The player
*/
class PlayerEntity : Entity {
private:
    KeyboardState* lstate;
    KeyboardState* kstate;

    BlockRef placeId = 0;
    WorldPos* lookingAt;
    WorldPos* lastLookingAt;


    void updateBlockLookAt() {
        enum PLACE_DISTANCE = 6;
        enum PLACE_ITER = 0.1;

        vec3 forwardVector = vec4(0, 0, PLACE_ITER, 1) * FcCamera.getRotationMatrix();
        vec3 ray = FcCamera.position;
        vec3 lastRay;
        foreach(i; 0..PLACE_DISTANCE/PLACE_ITER) {
            lastRay = ray;
            ray += forwardVector;
            auto rayBlock = WorldPos(vec3i(-cast(int)floor(ray.x), cast(int)floor(abs(ray.y)), -cast(int)floor(ray.z)));
            auto lastRayBlock = WorldPos(vec3i(-cast(int)floor(lastRay.x), cast(int)floor(abs(lastRay.y)), -cast(int)floor(lastRay.z)));
        
            Chunk chunk = world.getChunkAtWorldPos(rayBlock);
            if (chunk !is null && chunk.hasBlockAt(rayBlock)) {
                lookingAt = new WorldPos(rayBlock.x, rayBlock.y, rayBlock.z);
                lastLookingAt = new WorldPos(lastRayBlock.x, lastRayBlock.y, lastRayBlock.z);
                return;
            }
        }
        lookingAt = null;
        lastLookingAt = null;
    }

public:
    /**
        Constructs the player
    */
    this(World world) {
        super(world);
        this.position = vec3(0, -256, 0);
    }

    override
    void update() {
        enum MoveSpeed = 0.25;
        lstate = kstate;
        kstate = fcKeyboardGetState();
        vec2 mMotion = fcMouseMotion();

        if (fcGameGetRelativeMouse()) {
            FcCamera.rotation.y += radians(mMotion.x)*0.8;
            FcCamera.rotation.x += radians(mMotion.y)*0.8;
            FcCamera.rotation.x = clamp(FcCamera.rotation.x, -radians(90), radians(90));
            
            vec3 upVector = vec4(0, MoveSpeed, 0, 1);
            mat4 cameraRotMatr = mat4.yrotation(FcCamera.rotation.y);
            vec3 rightVector = vec4(MoveSpeed, 0, 0, 1) * cameraRotMatr;
            vec3 forwardVector = vec4(0, 0, MoveSpeed, 1) * cameraRotMatr;

            if (kstate.isKeyDown(Keys.W)) position += forwardVector;
            if (kstate.isKeyDown(Keys.S)) position -= forwardVector;
            if (kstate.isKeyDown(Keys.D)) position -= rightVector;
            if (kstate.isKeyDown(Keys.A)) position += rightVector;
            if (kstate.isKeyDown(Keys.LeftShift)) position += upVector;
            if (kstate.isKeyDown(Keys.Space)) position -= upVector;
        }

        FcCamera.position = vec3(position.x, position.y + 1, position.z);

        this.updateBlockLookAt();
        if (lookingAt) fcDrawBlockSelection(*lookingAt);

        fcDrawChunkBorder(chunkPosition);

        if (lstate !is null) {

            if (kstate.isKeyDown(Keys.R) && lstate.isKeyUp(Keys.R)) {
                
                TheWorld.forceMeshUpdates();
                //this.position = vec3(0, -256, 0);
            }

            if (kstate.isKeyDown(Keys.Q) && lstate.isKeyUp(Keys.Q)) {
                import engine.chunk.meshgen : MeshGenerator;
                TheWorld.clearChunks();
            }

            if (kstate.isKeyDown(Keys.T) && lstate.isKeyUp(Keys.T)) {
                ChunkProvider.preload();
            }

            if (lookingAt && kstate.isKeyDown(Keys.E) && lstate.isKeyUp(Keys.E)) {
                if (placeId == 0) {
                    TheWorld.setBlockAt(*lookingAt, 0);
                } else {
                    TheWorld.setBlockAt(*lastLookingAt, placeId);
                }
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

            if (kstate.isKeyDown(Keys.Four) && lstate.isKeyUp(Keys.Four)) {
                placeId = 3;
            }

            if (kstate.isKeyDown(Keys.Escape) && lstate.isKeyUp(Keys.Escape)) {
                fcGameSetRelativeMouse(!fcGameGetRelativeMouse);
            }
        }

    }
}