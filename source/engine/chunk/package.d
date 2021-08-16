module engine.chunk;
import engine;
import engine.render;
import engine.chunk.mesh;

public import engine.chunk.chunkprovider;
public import engine.chunk.chunkdbg;

/**
    The size of a chunk
*/
enum ChunkSize = 16;

/**
    The height of a chunk
*/
enum ChunkHeight = 512;

/**
    Internal store for blocks that's atomically swappable
*/
struct ChunkBlockStore {

    /**
        A list of blocks in the world
    */
    BlockRef[ChunkSize][ChunkHeight][ChunkSize] blocks;
}

/**
    Chunk position
*/
struct ChunkPos {
    /**
        X coordinate of chunk
    */
    int x;

    /**
        Z coordinate of chunk
    */
    int z;

    /**
        Returns the chunk as a vec2i
    */
    vec2i toVec2i() {
        return vec2i(x, z);
    }

    /**
        Returns the chunk as a vec2
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

    /**
        Gets whether a ChunkPos is in this area
    */
    bool isInArea(ChunkPos origin, int area) {
        area /= 2;
        return 
            x >= origin.x-area && x < origin.x+area &&
            z >= origin.z-area && z < origin.z+area;
    }
}

/**
    A chunk
*/
class Chunk {
package(engine):

    /**
        The world
    */
    World world;

    /**
        The mesh of the chunk
    */
    ChunkMesh mesh;

    /**
        The chunk block store
    */
    immutable(ChunkBlockStore)* store;

    /**
        Updates the memory store
    */
    void _storeUpdate(immutable(ChunkBlockStore)* newStore) {
        import core.atomic : atomicExchange;
        atomicExchange(&store, newStore);
    }

    bool meshInvalid;
    /**
        Invalidates the chunk's mesh and optionally does the same for the surrounding chunks
    */
    void updateMesh() {
        mesh.regenerate();
    }

public:

    ~this() {

        // NOTE: Chunk could be destroyed during generation.
        // destroy!false(mesh);
        destroy!false(store);
    }

    /**
        Position of the chunk in the world
    */
    ChunkPos position;

    /**
        Gets the world position of the chunk
    */
    vec3 worldPosition() {
        return vec3(position.x*ChunkSize, 0, position.z*ChunkSize);
    }

    /**
        Gets the world position of the chunk
    */
    vec3 worldPositionCenter() {
        return vec3((position.x+8)*ChunkSize, ChunkHeight/2, (position.z+8)*ChunkSize);
    }

    /**
        Initializes a chunk
    */
    this(World world, ChunkPos position) {
        this.world = world;
        this.position = position;
        this.mesh = new ChunkMesh(this);
        store = new ChunkBlockStore;
    }


    /**
        Initializes a chunk
    */
    this(World world, vec2i position) {
        this(world, ChunkPos(position.x, position.y));
    }

    /**
        Loads blocks
    */
    void setChunkBlocks(BlockRef[ChunkSize][ChunkHeight][ChunkSize] blocks) {
        this._storeUpdate(new ChunkBlockStore(blocks));
    }

    /**
        Loads blocks
    */
    void setChunkBlocks(ChunkBlockStore* store) {
        this._storeUpdate(cast(immutable(ChunkBlockStore)*)store);
    }

    /**
        Updates the chunk
    */
    void update() {
    }

    /**
        Invalidates the chunk's mesh and optionally does the same for the surrounding chunks
    */
    void invalidateMesh(bool invalidateOthers = true, bool highPriority = false) {
        mesh.regenerate(highPriority);
        if (invalidateOthers) {

            // Update surrounding chunks
            Chunk leftChunk = this.chunkLeft;
            Chunk rightChunk = this.chunkRight;
            Chunk frontChunk = this.chunkFront;
            Chunk backChunk = this.chunkBack;
            if (leftChunk) leftChunk.invalidateMesh(false, highPriority);
            if (rightChunk) rightChunk.invalidateMesh(false, highPriority);
            if (frontChunk) frontChunk.invalidateMesh(false, highPriority);
            if (backChunk) backChunk.invalidateMesh(false, highPriority);
        }
    }

    /**
        Invalidates the chunk's mesh and optionally does the same for the surrounding chunks
    */
    void invalidateAdjacent(bool invalidateOthers = true) {
        
        // Update surrounding chunks
        Chunk leftChunk = this.chunkLeft;
        Chunk rightChunk = this.chunkRight;
        Chunk frontChunk = this.chunkFront;
        Chunk backChunk = this.chunkBack;
        if (leftChunk) leftChunk.invalidateMesh(false);
        if (rightChunk) rightChunk.invalidateMesh(false);
        if (frontChunk) frontChunk.invalidateMesh(false);
        if (backChunk) backChunk.invalidateMesh(false);
    }

    /**
        Whether the chunk is ready
    */
    bool isReady;

    /**
        Draws the chunk
    */
    void draw() {
        mesh.draw();
    }

    /**
        Gets whether there's a block at the specified location
    */
    bool hasBlockAt(WorldPos blockPos) {
        blockPos = blockPos.wrapped();
        return this.store.blocks[blockPos.x][blockPos.y][blockPos.z] > 0;
    }

    /**
        Sets block in chunk
    */
    void setBlockAt(WorldPos blockPos, BlockRef block) {
        blockPos = blockPos.wrapped();

        auto store = *store;
        BlockRef[ChunkSize][ChunkHeight][ChunkSize] oldBlockList = store.blocks.dup;
        oldBlockList[blockPos.x][blockPos.y][blockPos.z] = block;

        this._storeUpdate(new ChunkBlockStore(oldBlockList));
        this.invalidateMesh(true, true);
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkFront() {
        return world.getChunkAt(ChunkPos(position.x, position.z+1));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkBack() {
        return world.getChunkAt(ChunkPos(position.x, position.z-1));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkLeft() {
        return world.getChunkAt(ChunkPos(position.x-1, position.z));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkRight() {
        return world.getChunkAt(ChunkPos(position.x+1, position.z));
    }

    World getWorld() {
        return world;
    }
}