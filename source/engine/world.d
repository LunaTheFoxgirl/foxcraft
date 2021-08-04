module engine.world;
import engine;
import engine.render;
import game.entities.player;

import core.sync.rwmutex : ReadWriteMutex;

/**
    Block height of the world
*/
enum WorldHeight = 256;

/**
    The world
*/
World TheWorld;

/**
    Chunk position in world
*/
struct WorldPos {
    /**
        X coordinate
    */
    int x;

    /**
        Y coordinate
    */
    int y;

    /**
        Z coordinate
    */
    int z;

    /**
        Constructs a WorldPos
    */
    this(int x, int y, int z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    /**
        Constructs a WorldPos
    */
    this(vec3i vec) {
        this.x = vec.x;
        this.y = vec.y;
        this.z = vec.z;
    }
}

/**
    The world
*/
class World {
private:
    uint seed;
    ReadWriteMutex chunkMutex;

    /**
        The loaded chunks in the world
    */
    Chunk[WorldPos] chunks;

public:

    /**
        Creates a new world
    */
    this(uint seed) {
        chunkMutex = new ReadWriteMutex();
        this.seed = seed;
        fcGameSetRelativeMouse(true);

        player = new PlayerEntity(this);

        foreach(cx; 0..16) {
            foreach(cy; 0..16) {
                foreach(cz; 0..16) {
                    if (cy < 16) {
                        Chunk chunk = new Chunk(this, vec3i(cx-8, cy, cz-8));
                        foreach(x; 0..ChunkSize) {
                            foreach(y; 0..ChunkSize) {
                                foreach(z; 0..ChunkSize) {
                                    chunk.blocks[x][y][z] = (cy*ChunkSize)+y == 255 ? 2 : 1;
                                }
                            }
                        }

                        this.addChunk(chunk);
                    } else {
                        // Adds empty chunk
                        Chunk chunk = new Chunk(this, vec3i(cx-8, cy, cz-8));
                        this.addChunk(chunk);
                    }
                }
            }
        }
    }

    /**
        Player entity
    */
    Entity player;

    /**
        Other entities
    */
    Entity[] entities;

    /**
        Gets the seed of the world
    */
    uint getSeed() { return seed; }

    /**
        Updates and draws the world
    */
    void update() {
        foreach(chunk; chunks) {
            chunk.draw();
        }

        // Updates player
        player.update();

        // Updates entities
        foreach(entity; entities) {
            entity.update();
        }
    }

    /**
        Adds a chunk in to the world
    */
    void addChunk(Chunk chunk) {
        WorldPos cPos = WorldPos(chunk.position);
        chunks[cPos] = chunk;
        chunks[cPos].invalidateMesh();
    }

    /**
        Gets the block at the specified position
    */
    Block getBlockAt(WorldPos position) {
        WorldPos chunkPos = WorldPos(position.x/ChunkSize, position.y/ChunkSize, position.z/ChunkSize);

        // Early return, no chunk found
        if (chunkPos !in chunks) return null;

        WorldPos blockPos;
        if (position.x < 0) blockPos.x = abs(ChunkSize-position.x)%ChunkSize-1;
        else blockPos.x = position.x&ChunkSize-1;
        if (position.y < 0) blockPos.y = abs(ChunkSize-position.y)%ChunkSize-1;
        else blockPos.y = position.y&ChunkSize-1;
        if (position.z < 0) blockPos.z = abs(ChunkSize-position.z)%ChunkSize-1;
        else blockPos.z = position.z&ChunkSize-1;

        import std.stdio : writeln;

        // Return block
        return fcGetBlock(chunks[chunkPos].blocks[blockPos.x][blockPos.y][blockPos.z]);
    }

    /**
        Gets the chunk at the specified position
    */
    Chunk getChunkAt(WorldPos position) {
        WorldPos chunkPos = WorldPos(position.x/ChunkSize, position.y/ChunkSize, position.z/ChunkSize);
        return chunkPos in chunks ? chunks[chunkPos] : null;
    }
}