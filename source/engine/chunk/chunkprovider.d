module engine.chunk.chunkprovider;
import engine;
import open_simplex_2.open_simplex_2_f;
import std.random : uniform;
import std.concurrency;
import core.atomic;
import core.thread : Thread, Fiber;
import core.time;
import std.stdio;
import std.algorithm.mutation : remove;

/**
    Creates a new chunk task
*/
struct ChunkTask {
    /**
        The position of the chunks
    */
    ChunkPos[] chunks;
}

/**
    A chunk task response
*/
struct ChunkTaskResponse {
    
    /**
        List of chunks
    */
    ChunkTaskResponseChunk chunk;
}

/**
    The underlying chunk
*/
struct ChunkTaskResponseChunk {
    /**
        Position of the chunk
    */
    ChunkPos position;

    /**
        List of generated blocks for chunk
    */
    BlockRef[ChunkSize][ChunkHeight][ChunkSize] blocks;
}

/**
    Provides chunks for the world
*/
class ChunkProvider {
private static:
    __gshared OpenSimplex2F osimplex;
    __gshared isRunning = false;
    __gshared isDoneProcessing = false;
    Fiber terrainGeneratorFiber;

    enum VIEW_DISTANCE = 32;
    enum VIEW_DISTANCE_HALF = VIEW_DISTANCE/2;

    ChunkPos[] scanForEmpty(ChunkPos origin) {
        ChunkPos[] toLoad;
        bool[VIEW_DISTANCE][VIEW_DISTANCE] checked;
        
        void scanEmptyChunks(ChunkPos pos) {
            ChunkPos position = ChunkPos(origin.x+(pos.x-VIEW_DISTANCE_HALF), origin.z+(pos.z-VIEW_DISTANCE_HALF));
            if (position !in TheWorld.chunks) toLoad ~= position;
            checked[pos.x][pos.z] = true;
            
            ChunkPos left = ChunkPos(pos.x-1, pos.z);
            ChunkPos right = ChunkPos(pos.x+1, pos.z);
            ChunkPos up = ChunkPos(pos.x, pos.z-1);
            ChunkPos down = ChunkPos(pos.x, pos.z+1);
            if (pos.x > 0 && !checked[pos.x-1][pos.z]) scanEmptyChunks(left);
            if (pos.x < VIEW_DISTANCE-1 && !checked[pos.x+1][pos.z]) scanEmptyChunks(right);
            if (pos.z > 0 && !checked[pos.x][pos.z-1]) scanEmptyChunks(up);
            if (pos.z < VIEW_DISTANCE-1 && !checked[pos.x][pos.z+1]) scanEmptyChunks(down);
        }

        // foreach(x; 0..VIEW_DISTANCE) {
        //     foreach(z; 0..VIEW_DISTANCE) {
        //         ChunkPos position = ChunkPos(origin.x+(x-VIEW_DISTANCE_HALF), origin.z+(z-VIEW_DISTANCE_HALF));
        //         if (position !in TheWorld.chunks) toLoad ~= position;
        //     }
        // }

        scanEmptyChunks(ChunkPos(VIEW_DISTANCE_HALF, VIEW_DISTANCE_HALF));
        return toLoad;
    }

    void threadGeneratorFunc() {
        ChunkPos playerChunkPos = TheWorld.player.chunkPosition;
        auto empty = scanForEmpty(playerChunkPos);

        size_t removed = 0;
        bool hasRemovedChunks;
        foreach(ChunkPos chunkPos, _; TheWorld.chunks) {
            if (!chunkPos.isInArea(playerChunkPos, VIEW_DISTANCE)) {
                TheWorld.chunks.remove(chunkPos);
                hasRemovedChunks = true;
                removed++;
            }
        }

        enum MAX_CHUNKS_PROCESS = 1000;
        int i;
        for(;i < empty.length && i < MAX_CHUNKS_PROCESS; i++) {
            Chunk chunk = new Chunk(TheWorld, empty[i]);
            chunk.setChunkBlocks(generateChunk(empty[i]));
            TheWorld.addChunk(chunk);
        }
    }

public static:

    /**
        Updates the terrain for the world
    */
    void update() {
        // terrainGeneratorFiber.call();
        threadGeneratorFunc();
    }

    /**
        Starts the ChunkProvider
    */
    void start() {
        terrainGeneratorFiber = new Fiber(() { threadGeneratorFunc(); });
    }

    BlockRef[ChunkSize][ChunkHeight][ChunkSize] generateChunk(immutable(ChunkPos) cpos) {
        BlockRef[ChunkSize][ChunkHeight][ChunkSize] blocks;
        foreach(x; 0..ChunkSize) {
            foreach(z; 0..ChunkSize) {
                double noise1 = osimplex.noise2(
                    cast(double)(1000+(cpos.x*ChunkSize)+x)*0.001, 
                    cast(double)(1000+(cpos.z*ChunkSize)+z)*0.001
                )*3;
                double noise2 = osimplex.noise2(
                    cast(double)((cpos.x*ChunkSize)+x)/100, 
                    cast(double)((cpos.z*ChunkSize)+z)/100
                );

                int height = cast(int)(
                    (256-16)+(((noise2*noise1)/2)*16)
                );

                foreach(y; 0..ChunkHeight) {
                    if (y == height) blocks[x][y][z] = 2;
                    else if (y < height) blocks[x][y][z] = 1;
                }
            }
        }
        return blocks;
    }

    /**
        Generates a chunk
    */
    Chunk generate(vec2i cpos) {
        Chunk chunk = new Chunk(TheWorld, cpos);
        chunk.setChunkBlocks(generateChunk(ChunkPos(cpos.x, cpos.y)));
        return chunk;
    }

    /**
        Preloads some terrain for the world
    */
    void preload() {
        osimplex = new OpenSimplex2F(uniform(0, ulong.max));
        ChunkPos playerChunkPos = ChunkPos(
            cast(int)(TheWorld.player.worldPosition.x/ChunkSize),
            cast(int)(TheWorld.player.worldPosition.z/ChunkSize)
        );

        int lDist = VIEW_DISTANCE_HALF;

        int hDist = lDist/2;
        foreach(cx; 0..lDist) {
            foreach(cz; 0..lDist) {
                vec2i cpos = vec2i((playerChunkPos.x-hDist)+cx, (playerChunkPos.z-hDist)+cz);
                Chunk chunk = generate(cpos);
                TheWorld.addChunk(chunk, false);
            }
        }
        
        TheWorld.forceMeshUpdates();
    }
}