module engine.world;
import engine;
import engine.render;
import game.entities.player;

import core.sync.rwmutex : ReadWriteMutex;
import open_simplex_2.open_simplex_2_f : OpenSimplex2F;

/**
    Block height of the world
*/
enum WorldHeight = 256;

/**
    The world
*/
__gshared World TheWorld;

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

    /**
        Returns this worldpos as a vec3i
    */
    vec3i toVec3i() {
        return vec3i(x, y, z);
    }

    /**
        Returns this worldpos as a float vec3
    */
    vec3 toVec3() {
        return vec3(x, y, z);
    }

    /**
        Returns this worldpos as a float vec3
    */
    vec2 toVec2() {
        return vec2(x, z);
    }

    /**
        Get the distance to an other WorldPos
    */
    int distance(WorldPos other) {
        return cast(int)toVec2().distance(other.toVec2);
    }

    bool isInArea(WorldPos origin, int area) {
        area /= 2;
        return 
            x >= origin.x-area && x < origin.x+area &&
            y >= origin.y-area && y < origin.y+area &&
            z >= origin.z-area && z < origin.z+area;
    }
}

/**
    The world
*/
class World {
private:
    uint seed;

public:

    /**
        Creates a new world
    */
    this(uint seed) {
        TheWorld = this;
        this.seed = seed;
        fcGameSetRelativeMouse(true);

        player = new PlayerEntity(this);
    }

    /**
        The loaded chunks in the world
    */
    Chunk[WorldPos] chunks;

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
        Force mesh updates to occur
    */
    void forceMeshUpdates() {
        foreach(chunk; chunks) {
            chunk.invalidateMesh(false);
        }
    }

    /**
        Updates and draws the world
    */
    void update() {
        
        // Updates player
        player.update();

        ChunkProvider.update();

        foreach(chunk; chunks) {
            chunk.draw();
        }

        // Updates entities
        foreach(entity; entities) {
            entity.update();
        }
    }

    /**
        Adds a chunk in to the world
    */
    void addChunk(Chunk chunk, bool invalidate = true) {
        WorldPos cPos = WorldPos(chunk.position);
        chunks[cPos] = chunk;
        if (invalidate) chunks[cPos].invalidateMesh();
    }

    /**
        Gets the block at the specified position
    */
    Block getBlockAt(WorldPos position) {
        WorldPos chunkPos = WorldPos(position.x/ChunkSize, position.y/ChunkSize, position.z/ChunkSize);

        // Early return, no chunk found
        if (chunkPos !in chunks) return null;

        WorldPos blockPos;
        if (position.x < 0) blockPos.x = abs(position.x)%ChunkSize-1;
        else blockPos.x = position.x&ChunkSize-1;
        if (position.y < 0) blockPos.y = abs(position.y)%ChunkSize-1;
        else blockPos.y = position.y&ChunkSize-1;
        if (position.z < 0) blockPos.z = abs(position.z)%ChunkSize-1;
        else blockPos.z = position.z&ChunkSize-1;

        import std.stdio : writeln;

        // Return block
        return fcGetBlock(chunks[chunkPos].store.blocks[blockPos.x][blockPos.y][blockPos.z]);
    }

    /**
        Gets the block at the specified position
    */
    void setBlockAt(WorldPos position, BlockRef block) {
        WorldPos chunkPos = WorldPos(position.x/ChunkSize, position.y/ChunkSize, position.z/ChunkSize);

        // Early return, no chunk found
        if (chunkPos !in chunks) return;

        WorldPos blockPos;
        if (position.x < 0) blockPos.x = abs(position.x)%ChunkSize-1;
        else blockPos.x = position.x&ChunkSize-1;
        if (position.y < 0) blockPos.y = abs(position.y)%ChunkSize-1;
        else blockPos.y = position.y&ChunkSize-1;
        if (position.z < 0) blockPos.z = abs(position.z)%ChunkSize-1;
        else blockPos.z = position.z&ChunkSize-1;

        import std.stdio : writeln;

        // Return block
        chunks[chunkPos].setBlockAt(blockPos, block);
    }

    /**
        Gets the chunk at the specified position
    */
    Chunk getChunkAtWorldPos(WorldPos position) {
        WorldPos chunkPos = WorldPos(position.x/ChunkSize, position.y/ChunkSize, position.z/ChunkSize);
        return chunkPos in chunks ? chunks[chunkPos] : null;
    }

    /**
        Gets the chunk at the specified position
    */
    Chunk getChunkAt(WorldPos position) {
        WorldPos chunkPos = WorldPos(position.x, position.y, position.z);
        return chunkPos in chunks ? chunks[chunkPos] : null;
    }
}