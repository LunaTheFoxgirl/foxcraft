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
            Chunk chf = chunk.chunkFront;
            Chunk chb = chunk.chunkBack;

            import core.atomic : atomicLoad;
            position = vec3(chunk.worldPosition.x, chunk.worldPosition.y, chunk.worldPosition.z);

            this.mstore = chunk.store;
            if (chl) this.cl = chl.store;
            else if (!chl || !chl.store) hasLeft = false;

            if (chr) this.cr = chr.store;
            else if (!chr || !chr.store) hasRight = false;

            if (chf) this.cf = chf.store;
            else if (!chf || !chf.store) hasFront = false;

            if (chb) this.cb = chb.store;
            else if (!chb || !chb.store) hasBack = false;
    }
    immutable(vec3) position;

    immutable(ChunkBlockStore)* mstore;
    immutable(ChunkBlockStore)* cl;
    bool hasLeft = true;

    immutable(ChunkBlockStore)* cr;
    bool hasRight = true;

    immutable(ChunkBlockStore)* cf;
    bool hasFront = true;

    immutable(ChunkBlockStore)* cb;
    bool hasBack = true;
}

/**
    Mesh generation task
*/
struct MeshGenTask {
    ChunkVertexBuffer* buffer;
    ChunkVertexBuffer* trbuffer;
    CMView data;

    /**
        Returns the distance of this task to the player
    */
    float distanceToPlayer() {
        return abs(data.position.distance(FcCamera.worldPosition));
    }
}

/**
    Mesh generation task return data
*/
struct MeshGenResponse {
    ChunkVertexBuffer* buffer;
    ChunkVertexBuffer* trbuffer;
    immutable(CMData[]) data;
    immutable(CMData[]) trdata;
}

/**
    The mesh generator
*/
class MeshGenerator {
private static:

    CMData[][2] generateMesh(CMView data) {
        CMData[] bufferToWrite;
        CMData[] tbufferToWrite;

        for(int y; y < ChunkHeight; y++) {
            for(int z; z < ChunkSize; z++) {
                for(int x; x < ChunkSize; x++) {

                    // Air blocks create no meshed part
                    if (data.mstore.blocks[x][y][z] == 0) continue;

                    Block block = fcGetBlock(data.mstore.blocks[x][y][z]);

                    // Skip blocks with invalid IDs; TODO: make those blocks a special placeholder block
                    if (block is null) continue;

                    bool blockTr = block.isTransparent;

                    bool blockFreeLeft =    
                        (x > 0 && (
                            data.mstore.blocks[x-1][y][z] == 0 ||
                            (!blockTr && fcGetBlock(data.mstore.blocks[x-1][y][z]).isTransparent)
                        )) || 
                        (x == 0 && data.hasLeft && (
                            data.cl.blocks[ChunkSize-1][y][z] == 0 ||
                            (!blockTr && fcGetBlock(data.cl.blocks[ChunkSize-1][y][z]).isTransparent)
                        )) || 
                        (!data.hasLeft && x == 0);

                    bool blockFreeRight =   
                        (x < ChunkSize-1 && (
                            data.mstore.blocks[x+1][y][z] == 0 ||
                            (!blockTr && fcGetBlock(data.mstore.blocks[x+1][y][z]).isTransparent)
                        )) || 
                        (x == ChunkSize-1 && data.hasRight && (
                            data.cr.blocks[0][y][z] == 0 ||
                            (!blockTr && fcGetBlock(data.cr.blocks[0][y][z]).isTransparent)
                        )) || 
                        (!data.hasRight && x == ChunkSize-1);

                    bool blockFreeBack =    
                        (z > 0  && (
                            data.mstore.blocks[x][y][z-1] == 0 ||
                            (!blockTr && fcGetBlock(data.mstore.blocks[x][y][z-1]).isTransparent)
                        )) || 
                        (z == 0 && data.hasBack && (
                            data.cb.blocks[x][y][ChunkSize-1] == 0 ||
                            (!blockTr && fcGetBlock(data.cb.blocks[x][y][ChunkSize-1]).isTransparent)
                        )) || 
                        (!data.hasBack && z == 0);
                    
                    bool blockFreeFront = 
                        (z < ChunkSize-1 && (
                            data.mstore.blocks[x][y][z+1] == 0 ||
                            (!blockTr && fcGetBlock(data.mstore.blocks[x][y][z+1]).isTransparent)
                        )) || 
                        (z == ChunkSize-1 && data.hasFront && (
                            data.cf.blocks[x][y][0] == 0 ||
                            (!blockTr && fcGetBlock(data.cf.blocks[x][y][0]).isTransparent)
                        )) || 
                        (!data.hasFront && z == ChunkSize-1);

                    bool blockFreeBottom = 
                        (y > 0 && (
                            data.mstore.blocks[x][y-1][z] == 0 || 
                            (!blockTr && fcGetBlock(data.mstore.blocks[x][y-1][z]).isTransparent)
                        )) || 
                        y == 0;
                    
                    bool blockFreeTop =     
                        (y < ChunkHeight-1 && (
                            data.mstore.blocks[x][y+1][z] == 0 || 
                            (!blockTr && fcGetBlock(data.mstore.blocks[x][y+1][z]).isTransparent)
                        )) || 
                        y == ChunkHeight-1;

                    vec3 cpos = vec3(x, y, z);

                    // Top cap
                    if (blockFreeTop) {
                        vec4 uvs = fcAtlasGet(block.textures[2]);
                        if (blockTr) tbufferToWrite ~= ([
                            CMData(cpos+voxelVerts[0], vec2(uvs.x, uvs.y), 1.0),
                            CMData(cpos+voxelVerts[1], vec2(uvs.x, uvs.w), 1.0),
                            CMData(cpos+voxelVerts[2], vec2(uvs.z, uvs.y), 1.0),
                            CMData(cpos+voxelVerts[3], vec2(uvs.z, uvs.y), 1.0),
                            CMData(cpos+voxelVerts[4], vec2(uvs.x, uvs.w), 1.0),
                            CMData(cpos+voxelVerts[5], vec2(uvs.z, uvs.w), 1.0),
                        ]);
                        else bufferToWrite ~= ([
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
                        if (blockTr) tbufferToWrite ~= ([
                            CMData(cpos+voxelVerts[6],  vec2(uvs.x, uvs.y), 0.3),
                            CMData(cpos+voxelVerts[7],  vec2(uvs.x, uvs.w), 0.3),
                            CMData(cpos+voxelVerts[8],  vec2(uvs.z, uvs.y), 0.3),
                            CMData(cpos+voxelVerts[9],  vec2(uvs.z, uvs.y), 0.3),
                            CMData(cpos+voxelVerts[10], vec2(uvs.x, uvs.w), 0.3),
                            CMData(cpos+voxelVerts[11], vec2(uvs.z, uvs.w), 0.3),
                        ]);
                        else bufferToWrite ~= ([
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
                        if (blockTr) tbufferToWrite ~= ([
                            CMData(cpos+voxelVerts[18], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[19], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[20], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[21], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[22], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[23], vec2(uvs.z, uvs.w), 0.5),
                        ]);
                        else bufferToWrite ~= ([
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
                        if (blockTr) tbufferToWrite ~= ([
                            CMData(cpos+voxelVerts[12], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[13], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[14], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[15], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[16], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[17], vec2(uvs.z, uvs.w), 0.5),
                        ]);
                        else bufferToWrite ~= ([
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
                        if (blockTr) tbufferToWrite ~= ([
                            CMData(cpos+voxelVerts[24], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[25], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[26], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[27], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[28], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[29], vec2(uvs.z, uvs.w), 0.5),
                        ]);
                        else bufferToWrite ~= ([
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
                        if (blockTr) tbufferToWrite ~= ([
                            CMData(cpos+voxelVerts[30], vec2(uvs.x, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[31], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[32], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[33], vec2(uvs.z, uvs.y), 0.5),
                            CMData(cpos+voxelVerts[34], vec2(uvs.x, uvs.w), 0.5),
                            CMData(cpos+voxelVerts[35], vec2(uvs.z, uvs.w), 0.5),
                        ]);
                        else bufferToWrite ~= ([
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
        return [bufferToWrite, tbufferToWrite];
    }

    __gshared bool shouldRun;
    void meshGenThreadFunc() {
        import std.stdio : writeln;
        import core.memory : GC;

        setMaxMailboxSize(thisTid, 0, OnCrowding.ignore);
        auto owner = ownerTid;
        MeshGenTask*[] taskQueue;
        while (atomicLoad(shouldRun)) {
            try {
                while (atomicLoad(shouldRun) && receiveTimeout(100.msecs, (immutable(MeshGenTask)* task) {
                    taskQueue ~= cast(MeshGenTask*)task;
                })) { }

                if (taskQueue.length > 0) {
                    // import std.math : cmp;
                    // taskQueue.sort!((a, b) => cmp(a.distanceToPlayer(), b.distanceToPlayer()) < 0);

                    import std.parallelism : parallel;

                    // TODO: This is using a lot of memory, make it not do that
                    //for (size_t i; i < taskQueue.length; i++) {
                    foreach(ctask; parallel(taskQueue)) {
                        if (!atomicLoad(shouldRun)) continue;
                        // Generate a mesh for the task

                        auto mesh = generateMesh(ctask.data);
                        // Send it back to our main thread so that it can be sent on to OpenGL
                        send(
                            owner, 
                            cast(immutable(MeshGenResponse)*)new MeshGenResponse(
                                ctask.buffer, 
                                ctask.trbuffer, 
                                cast(immutable(CMData[]))mesh[0],
                                cast(immutable(CMData[]))mesh[1]
                            )
                        );
                    }
                    taskQueue.length = 0;
                }
            } catch(Exception ex) {
                import std.stdio : writeln;
                writeln("[ERROR] ChunkMesher: ", ex.msg);
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

    size_t totalCounter;
    void update() {
        size_t counter = 0;
        enum COUNTER_MAX_FRAME = 1024;
        while(counter < COUNTER_MAX_FRAME && receiveTimeout(-1.msecs, (immutable(MeshGenResponse)* response) {

            // Return if buffer is null
            if (response.buffer is null) return;

            (cast(ChunkVertexBuffer)*response.buffer).upload(response.data);
            (cast(ChunkVertexBuffer)*response.trbuffer).upload(response.trdata);
        })) counter++;
    }

    /**
        enqueues the specificed mesh generator task
    */
    void enqueue(immutable(MeshGenTask)* task, bool highPriority = false) {
        if (task.buffer is null) return; // Can't enqueue a dead buffer
        if (highPriority) prioritySend(meshGeneratorThread, task);
        else send(meshGeneratorThread, task);
    }
}