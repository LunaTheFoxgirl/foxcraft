module engine.chunk.meshgen;
import engine.chunk.mesh;
import engine;
import engine.render;
import std.concurrency;
import core.atomic;
import core.time;
import core.sync.mutex;
import core.thread;
import std.algorithm.sorting;
import std.algorithm.mutation;

private {
    vec3[] voxelVerts = [
        // TOP
        vec3(0, 1, 0),
        vec3(0, 1, 1),
        vec3(1, 1, 0),

        vec3(1, 1, 0),
        vec3(0, 1, 1),
        vec3(1, 1, 1),

        // BOTTOM
        vec3(0, 0, 0),
        vec3(1, 0, 0),
        vec3(0, 0, 1),

        vec3(0, 0, 1),
        vec3(1, 0, 0),
        vec3(1, 0, 1),

        // FRONT
        vec3(0, 1, 1),
        vec3(0, 0, 1),
        vec3(1, 1, 1),
        
        vec3(1, 1, 1),
        vec3(0, 0, 1),
        vec3(1, 0, 1),

        // BACK
        vec3(0, 1, 0),
        vec3(1, 1, 0),
        vec3(0, 0, 0),
        
        vec3(0, 0, 0),
        vec3(1, 1, 0),
        vec3(1, 0, 0),

        // RIGHT
        vec3(1, 1, 0),
        vec3(1, 1, 1),
        vec3(1, 0, 0),
        
        vec3(1, 0, 0),
        vec3(1, 1, 1),
        vec3(1, 0, 1),

        // LEFT
        vec3(0, 1, 0),
        vec3(0, 0, 0),
        vec3(0, 1, 1),
        
        vec3(0, 1, 1),
        vec3(0, 0, 0),
        vec3(0, 0, 1),
    ];
}

/**
    View in to chunk

    TODO: Access the chunk data atomically
*/
struct CMView {
    this(ref Chunk chunk) {
            Chunk chl = chunk.chunkLeft;
            Chunk chr = chunk.chunkRight;
            Chunk chu = chunk.chunkTop;
            Chunk chd = chunk.chunkBottom;
            Chunk chf = chunk.chunkFront;
            Chunk chb = chunk.chunkBack;

            this.blocks = &chunk.blocks;
            if (chl) this.cl = &chl.blocks;
            else if (!chl || !chl.isReady) hasLeft = false;

            if (chr) this.cr = &chr.blocks;
            else if (!chr || !chr.isReady) hasRight = false;

            if (chu) this.cu = &chu.blocks;
            else if (!chu || !chu.isReady) hasUp = false;

            if (chd) this.cd = &chd.blocks;
            else if (!chd || !chd.isReady) hasDown = false;

            if (chf) this.cf = &chf.blocks;
            else if (!chf || !chf.isReady) hasFront = false;

            if (chb) this.cb = &chb.blocks;
            else if (!chb || !chb.isReady) hasBack = false;
    }

    BlockRef[ChunkSize][ChunkSize][ChunkSize]* blocks;
    BlockRef[ChunkSize][ChunkSize][ChunkSize]* cl;
    bool hasLeft = true;

    BlockRef[ChunkSize][ChunkSize][ChunkSize]* cr;
    bool hasRight = true;

    BlockRef[ChunkSize][ChunkSize][ChunkSize]* cu;
    bool hasUp = true;

    BlockRef[ChunkSize][ChunkSize][ChunkSize]* cd;
    bool hasDown = true;

    BlockRef[ChunkSize][ChunkSize][ChunkSize]* cf;
    bool hasFront = true;

    BlockRef[ChunkSize][ChunkSize][ChunkSize]* cb;
    bool hasBack = true;
}

/**
    Mesh generation task
*/
struct MeshGenTask {
    ChunkMesh chunk;
    CMView data;

    /**
        Returns the distance of this task to the player
    */
    float distanceToPlayer() {
        return chunk.chunk.worldPosition.distance(TheWorld.player.position);
    }
}

/**
    Mesh generation task return data
*/
struct MeshGenResponse {
    ChunkMesh chunk;
    immutable(CMData[]) data;
}

/**
    The mesh generator
*/
class MeshGenerator {
private static:
    __gshared bool shouldRun;
    __gshared MeshGenTask*[] taskQueue;

    CMData[] generateMesh(CMView data) {
        CMData[] bufferToWrite;

        for(int y; y < ChunkSize; y++) {
            for(int z; z < ChunkSize; z++) {
                for(int x; x < ChunkSize; x++) {

                    // Air blocks create no meshed part
                    if ((*data.blocks)[x][y][z] == 0) continue;

                    Block block = fcGetBlock((*data.blocks)[x][y][z]);

                    // Skip blocks with invalid IDs; TODO: make those blocks a special placeholder block
                    if (block is null) continue;

                    bool blockFreeLeft =    (x > 0              && (*data.blocks)[x-1][y][z] == 0) || (x == 0 && data.hasLeft && (*data.cl)[ChunkSize-1][y][z] == 0)      || (!data.hasLeft && x == 0);
                    bool blockFreeRight =   (x < ChunkSize-1    && (*data.blocks)[x+1][y][z] == 0) || (x == ChunkSize-1 && data.hasRight && (*data.cr)[0][y][z] == 0)     || (!data.hasRight && x == ChunkSize-1);


                    import std.stdio : writefln;
                    //if (y == 0) writefln("y=%s, isOnEdge=%s, hasDown=%s, cdl=%s", y, (!data.hasDown && y == 0), data.hasDown, data.cd.length);

                    bool blockFreeBottom =  (y > 0              && (*data.blocks)[x][y-1][z] == 0) || (y == 0 && data.hasDown && (*data.cd)[x][ChunkSize-1][z] == 0)      || (!data.hasDown && y == 0);
                    bool blockFreeTop =     (y < ChunkSize-1    && (*data.blocks)[x][y+1][z] == 0) || (y == ChunkSize-1 && data.hasUp && (*data.cu)[x][0][z] == 0)        || (!data.hasUp && y == ChunkSize-1);

                    bool blockFreeBack =    (z > 0              && (*data.blocks)[x][y][z-1] == 0) || (z == 0 && data.hasBack && (*data.cb)[x][y][ChunkSize-1] == 0)      || (!data.hasBack && z == 0);
                    bool blockFreeFront =   (z < ChunkSize-1    && (*data.blocks)[x][y][z+1] == 0) || (z == ChunkSize-1 && data.hasFront && (*data.cf)[x][y][0] == 0)    || (!data.hasFront && z == ChunkSize-1);

                    vec3 cpos = vec3(x, y, z);

                    // Top cap
                    if (blockFreeTop) {
                        vec4 uvs = fcAtlasGet(block.textures[2]);

                        bufferToWrite ~= ([
                            CMData(cpos+voxelVerts[0], vec2(uvs.x, uvs.y), 1.0),
                            CMData(cpos+voxelVerts[1], vec2(uvs.x, uvs.w), 1.0),
                            CMData(cpos+voxelVerts[2], vec2(uvs.z, uvs.y), 1.0),
                            CMData(cpos+voxelVerts[3], vec2(uvs.z, uvs.y), 1.0),
                            CMData(cpos+voxelVerts[4], vec2(uvs.x, uvs.w), 1.0),
                            CMData(cpos+voxelVerts[5], vec2(uvs.z, uvs.w), 1.0),
                        ]);
                    }
                    

                    // Bottom cap
                    if (blockFreeBottom) {
                        vec4 uvs = fcAtlasGet(block.textures[3]);
                        bufferToWrite ~= ([
                            CMData(cpos+voxelVerts[6],  vec2(uvs.x, uvs.y), 0.3),
                            CMData(cpos+voxelVerts[7],  vec2(uvs.x, uvs.w), 0.3),
                            CMData(cpos+voxelVerts[8],  vec2(uvs.z, uvs.y), 0.3),
                            CMData(cpos+voxelVerts[9],  vec2(uvs.z, uvs.y), 0.3),
                            CMData(cpos+voxelVerts[10], vec2(uvs.x, uvs.w), 0.3),
                            CMData(cpos+voxelVerts[11], vec2(uvs.z, uvs.w), 0.3),
                        ]);
                    }
                    

                    // Back cap
                    if (blockFreeBack) {
                        vec4 uvs = fcAtlasGet(block.textures[1]);
                        bufferToWrite ~= ([
                            CMData(cpos+voxelVerts[18], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[19], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[20], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[21], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[22], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[23], vec2(uvs.z, uvs.w), 0.5),
                        ]);
                    }
                    

                    // Front cap
                    if (blockFreeFront) {
                        vec4 uvs = fcAtlasGet(block.textures[0]);
                        bufferToWrite ~= ([
                            CMData(cpos+voxelVerts[12], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[13], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[14], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[15], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[16], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[17], vec2(uvs.z, uvs.w), 0.5),
                        ]);
                    }
                    

                    // Right cap
                    if (blockFreeRight) {
                        vec4 uvs = fcAtlasGet(block.textures[5]);
                        bufferToWrite ~= ([
                            CMData(cpos+voxelVerts[24], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[25], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[26], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[27], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[28], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[29], vec2(uvs.z, uvs.w), 0.5),
                        ]);
                    }
                    

                    // Left cap
                    if (blockFreeLeft) {
                        vec4 uvs = fcAtlasGet(block.textures[4]);
                        bufferToWrite ~= ([
                            CMData(cpos+voxelVerts[30], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[31], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[32], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[33], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[34], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[35], vec2(uvs.z, uvs.w), 0.5),
                        ]); 
                    }
                }
            }
        }
        return bufferToWrite;
    }

    void meshGenThreadFunc() {
        setMaxMailboxSize(thisTid, 0, OnCrowding.ignore);
        while (atomicLoad(shouldRun)) {
            try {
                receiveTimeout(-1.msecs, (immutable(MeshGenTask)* task) {
                    taskQueue ~= cast(MeshGenTask*)task;

                    import std.math : cmp;
                    taskQueue.sort!((a, b) => cmp(b.distanceToPlayer(), a.distanceToPlayer()) > 0);
                });

                if (taskQueue.length > 0) {
                    // Get the next task and remove it from the queue, we need to unlock as fast as possible.
                    MeshGenTask* ctask = taskQueue[0];
                    taskQueue = taskQueue[1..$];

                    auto data = generateMesh(ctask.data);
                    destroy(ctask.data);
                    send(ownerTid, cast(immutable(MeshGenResponse)*)new MeshGenResponse(ctask.chunk, data.idup));
                } 
                Thread.sleep(10.msecs);
            } catch (Exception ex) {
                import std.stdio;
                writeln(ex.msg);
            }
        }
    }

    Tid meshGeneratorThread;
public static:
    void start() {
        if (!atomicLoad(shouldRun)) {
            atomicStore(shouldRun, true);
            setMaxMailboxSize(thisTid(), 0, OnCrowding.ignore);
            meshGeneratorThread = spawn({
                MeshGenerator.meshGenThreadFunc();
            });
        }
    }

    void stop() {
        atomicStore(shouldRun, false);
    }

    void update() {
        receiveTimeout(-1.msecs, (immutable(MeshGenResponse)* response) {
            ChunkMesh rchunk = cast(ChunkMesh)response.chunk;
            rchunk.buffer.pass(new immutable(CMDataArr)(response.data));
            rchunk.buffer.upload();
        });
    }

    /**
        enqueues the specificed mesh generator task
    */
    void enqueue(immutable(MeshGenTask)* task) {
        send(meshGeneratorThread, task);
    }
}