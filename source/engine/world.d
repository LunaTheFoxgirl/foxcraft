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
        import std.random : uniform;
        OpenSimplex2F osimplex = new OpenSimplex2F(uniform(0, ulong.max));
        

        foreach(cx; 0..32) {
            foreach(cy; 0..32) {
                foreach(cz; 0..32) {
                    Chunk chunk = new Chunk(this, vec3i(cx-16, cy, cz-16));
                    BlockRef[ChunkSize][ChunkSize][ChunkSize] blocks;
                    foreach(x; 0..ChunkSize) {
                        foreach(y; 0..ChunkSize) {
                            foreach(z; 0..ChunkSize) {
                                double noise1 = osimplex.noise2(
                                    cast(double)(1000+(cx*ChunkSize)+x)*0.001, 
                                    cast(double)(1000+(cz*ChunkSize)+z)*0.001
                                )*3;
                                double noise2 = osimplex.noise2(
                                    cast(double)((cx*ChunkSize)+x)/100, 
                                    cast(double)((cz*ChunkSize)+z)/100
                                );

                                int height = cast(int)(
                                    (256-16)+(((noise2*noise1)/2)*16)
                                );
                                if (x % 8 == 0 && z % 8 == 0) height += 2;
                                height = 255;

                                if ((cy*ChunkSize)+y == height) blocks[x][y][z] = 2;
                                else if ((cy*ChunkSize)+y < height) blocks[x][y][z] = 1;
                            }
                        }
                    }
                    chunk.setChunkBlocks(blocks);
                    this.addChunk(chunk, false);
                }
            }
        }
        this.forceMeshUpdates();
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