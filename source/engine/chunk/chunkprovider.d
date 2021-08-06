module engine.chunk.chunkprovider;
import engine;
import open_simplex_2.open_simplex_2_f;
import std.random : uniform;
import std.concurrency;
import core.atomic;
import core.thread : Thread;
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
    WorldPos[] chunks;
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
    WorldPos position;

    /**
        List of generated blocks for chunk
    */
    BlockRef[ChunkSize][ChunkSize][ChunkSize] blocks;
}

/**
    Provides chunks for the world
*/
class ChunkProvider {
private static:
    __gshared OpenSimplex2F osimplex;
    __gshared isRunning = false;
    __gshared isDoneProcessing = false;

    Tid terrainGeneratorTask;

    enum VIEW_DISTANCE = 24;
    enum VIEW_DISTANCE_HALF = VIEW_DISTANCE/2;

    void terrainGeneratorFunc() {
        setMaxMailboxSize(thisTid, 0, OnCrowding.ignore);
        immutable(WorldPos[])* chunksToLoad;
        size_t lastIdx = 0;
        while(atomicLoad(isRunning)) {
            // Get *latest* mailbox item
            while(receiveTimeout(0.msecs, (immutable(ChunkTask)* chunkt) {
                chunksToLoad = &chunkt.chunks;
                lastIdx = 0;
            })) { }

            if (chunksToLoad !is null) {
                enum MAX_CHUNKS_LOAD = 1024;
                int loaded;
                while (loaded < MAX_CHUNKS_LOAD && lastIdx < chunksToLoad.length) {
                    auto chunk = (*chunksToLoad)[lastIdx++];
                    send(ownerTid, 
                        cast(immutable(ChunkTaskResponse)*)new ChunkTaskResponse(
                            ChunkTaskResponseChunk(chunk, generateChunk(cast(WorldPos)chunk))
                        )
                    );
                }
                if (lastIdx == chunksToLoad.length) chunksToLoad = null;
                
            } else {
                Thread.sleep(50.msecs);
            }
        }
    }

    WorldPos[] scanForEmpty(WorldPos origin) {
        WorldPos[] toLoad;
        foreach(x; 0..VIEW_DISTANCE) {
            foreach(y; 0..VIEW_DISTANCE) {
                foreach(z; 0..VIEW_DISTANCE) {
                    WorldPos position = WorldPos(origin.x+(x-VIEW_DISTANCE_HALF), origin.y+(y-VIEW_DISTANCE_HALF), origin.z+(z-VIEW_DISTANCE_HALF));
                    if (position !in TheWorld.chunks) toLoad ~= position;
                }
            }
        }
        return toLoad;
    }

public static:
    /**
        Submits empty chunks
    */
    void submitEmptyChunks() {
        WorldPos playerChunkPos = WorldPos(
            cast(int)(TheWorld.player.worldPosition.x/ChunkSize),
            cast(int)(TheWorld.player.worldPosition.y/ChunkSize), 
            cast(int)(TheWorld.player.worldPosition.z/ChunkSize)
        );

        auto empty = scanForEmpty(playerChunkPos);
        if (empty.length > 0) {
            send(terrainGeneratorTask, new immutable(ChunkTask)(cast(immutable(WorldPos[]))empty));
        }
    }

    /**
        Updates the terrain for the world
    */
    void update() {
        WorldPos playerChunkPos = WorldPos(
            cast(int)(TheWorld.player.worldPosition.x/ChunkSize),
            cast(int)(TheWorld.player.worldPosition.y/ChunkSize), 
            cast(int)(TheWorld.player.worldPosition.z/ChunkSize)
        );
        
        bool hasRemovedChunks;
        foreach(WorldPos chunkPos, _; TheWorld.chunks) {
            if (!chunkPos.isInArea(playerChunkPos, VIEW_DISTANCE)) {
                destroy(TheWorld.chunks[chunkPos]);
                TheWorld.chunks.remove(chunkPos);
                hasRemovedChunks = true;
            }
        }
        if (hasRemovedChunks) submitEmptyChunks();

        while (receiveTimeout(0.msecs, (immutable(ChunkTaskResponse)* response) {
            auto chunkp = response.chunk;
                WorldPos pos = cast(WorldPos)chunkp.position;
                Chunk chunk = new Chunk(TheWorld, pos.toVec3i);
                chunk.setChunkBlocks(chunkp.blocks);
                TheWorld.addChunk(chunk);
                destroy(response);
        })) { }
    }

    /**
        Starts the ChunkProvider
    */
    void start() {
        if (!atomicLoad(isRunning)) {
            atomicStore(isRunning, true);
            terrainGeneratorTask = spawn(&terrainGeneratorFunc);
            submitEmptyChunks();
        }
    }

    /**
        Stops the ChunkProvider
    */
    void stop() {
        atomicStore(isRunning, false);
    }

    immutable(BlockRef[ChunkSize][ChunkSize][ChunkSize]) generateChunk(immutable(WorldPos) cpos) {
        BlockRef[ChunkSize][ChunkSize][ChunkSize] blocks;
        foreach(x; 0..ChunkSize) {
            foreach(y; 0..ChunkSize) {
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

                    if ((cpos.y*ChunkSize)+y == height) blocks[x][y][z] = 2;
                    else if ((cpos.y*ChunkSize)+y < height) blocks[x][y][z] = 1;
                }
            }
        }
        return blocks;
    }

    /**
        Generates a chunk
    */
    Chunk generate(vec3i cpos) {
        Chunk chunk = new Chunk(TheWorld, cpos);
        chunk.setChunkBlocks(generateChunk(WorldPos(cpos.x, cpos.y, cpos.z)));
        return chunk;
    }

    /**
        Preloads some terrain for the world
    */
    void preload() {
        osimplex = new OpenSimplex2F(uniform(0, ulong.max));
        WorldPos playerChunkPos = WorldPos(
            cast(int)(TheWorld.player.worldPosition.x/ChunkSize),
            cast(int)(TheWorld.player.worldPosition.y/ChunkSize), 
            cast(int)(TheWorld.player.worldPosition.z/ChunkSize)
        );

        foreach(cx; 0..8) {
            foreach(cy; 0..8) {
                foreach(cz; 0..8) {
                    vec3i cpos = vec3i((playerChunkPos.x-4)+cx, (playerChunkPos.y-4)+cy, (playerChunkPos.z-4)+cz);
                    Chunk chunk = generate(cpos);
                    TheWorld.addChunk(chunk, false);
                }
            }
        }
        
        TheWorld.forceMeshUpdates();
    }
}