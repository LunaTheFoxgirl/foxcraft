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

    ChunkPos toChunkPos() {
        return ChunkPos(
            cast(int)floor(cast(float)x/ChunkSize),
            cast(int)floor(cast(float)z/ChunkSize)
        );
    }

    WorldPos wrapped() {
        return WorldPos(
            (x < 0 ? ChunkSize-(x*-1)%ChunkSize : x)%ChunkSize,
            clamp(y, 0, ChunkHeight-1),
            (z < 0 ? ChunkSize-(z*-1)%ChunkSize : z)%ChunkSize,
        );
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
    Chunk[ChunkPos] chunks;

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
        chunks.rehash();
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

        foreach(chunk; chunks) chunk.draw();
        foreach(chunk; chunks) chunk.drawTransparent();
        

        // Updates entities
        foreach(entity; entities) {
            entity.update();
        }
    }

    /**
        Adds a chunk in to the world
    */
    void addChunk(Chunk chunk, bool invalidate = true) {
        chunks[chunk.position] = chunk;
        chunks.rehash();
        if (invalidate) chunks[chunk.position].invalidateMesh();
    }

    /**
        Removes a chunk from the world
    */
    void removeChunk(ChunkPos position) {
        destroy!false(chunks[position]);
        TheWorld.chunks.remove(position);
    }

    void clearChunks() {
        import core.memory : GC;
        foreach(pos; chunks.keys) {
            removeChunk(pos);
        }
        chunks.rehash();
    }

    /**
        Gets the block at the specified position
    */
    Block getBlockAt(WorldPos position) {
        ChunkPos chunkPos = position.toChunkPos();

        // Early return, no chunk found
        if (chunkPos !in chunks) return null;

        WorldPos blockPos = position.wrapped();

        // Return block
        return fcGetBlock(chunks[chunkPos].store.blocks[blockPos.x][blockPos.y][blockPos.z]);
    }

    /**
        Gets the block at the specified position
    */
    void setBlockAt(WorldPos position, BlockRef block) {
        ChunkPos chunkPos = position.toChunkPos();

        // Early return, no chunk found
        if (chunkPos !in chunks) return;

        WorldPos blockPos = position.wrapped();

        // Return block
        chunks[chunkPos].setBlockAt(blockPos, block);
    }

    /**
        Gets the chunk at the specified position
    */
    Chunk getChunkAtWorldPos(WorldPos position) {
        ChunkPos chunkPos = position.toChunkPos();
        return chunkPos in chunks ? chunks[chunkPos] : null;
    }

    /**
        Gets the chunk at the specified position
    */
    Chunk getChunkAt(ChunkPos position) {
        return position in chunks ? chunks[position] : null;
    }
}