module engine.chunk;
import engine;
import engine.render;
import engine.chunk.mesh;

public import engine.chunk.chunkprovider;

/**
    The size of a chunk
*/
enum ChunkSize = 16;

/**
    The square size of a chunk
*/
enum ChunkSizeSquared = ChunkSize*ChunkSize;

/**
    The cube size of a chunk
*/
enum ChunkSizeCubed = ChunkSizeSquared*ChunkSizeSquared;

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
        A list of blocks in the world
    */
    BlockRef[ChunkSize][ChunkSize][ChunkSize] blocks;

public:

    /**
        Position of the chunk in the world
    */
    vec3i position;

    vec3 worldPosition() {
        return vec3(position.x*ChunkSize, position.y*ChunkSize, position.z*ChunkSize);
    }

    /**
        Initializes a chunk
    */
    this(World world, vec3i position) {
        this.world = world;
        this.position = position;
        this.mesh = new ChunkMesh(this);
    }

    /**
        Updates the chunk
    */
    void update() {
    }

    /**
        Invalidates the chunk's mesh and optionally does the same for the surrounding chunks
    */
    void invalidateMesh(bool invalidateOthers = true) {
        mesh.regenerate();
        if (invalidateOthers) {

            // Update surrounding chunks
            Chunk leftChunk = this.chunkLeft;
            Chunk rightChunk = this.chunkRight;
            Chunk topChunk = this.chunkTop;
            Chunk bottomChunk = this.chunkBottom;
            Chunk frontChunk = this.chunkFront;
            Chunk backChunk = this.chunkBack;
            if (leftChunk) leftChunk.invalidateMesh(false);
            if (rightChunk) rightChunk.invalidateMesh(false);
            if (topChunk) topChunk.invalidateMesh(false);
            if (bottomChunk) bottomChunk.invalidateMesh(false);
            if (frontChunk) frontChunk.invalidateMesh(false);
            if (backChunk) backChunk.invalidateMesh(false);
        }
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
        if (blockPos.x < 0) blockPos.x = abs(blockPos.x)%ChunkSize-1;
        else blockPos.x = blockPos.x&ChunkSize-1;
        if (blockPos.y < 0) blockPos.y = abs(blockPos.y)%ChunkSize-1;
        else blockPos.y = blockPos.y&ChunkSize-1;
        if (blockPos.z < 0) blockPos.z = abs(blockPos.z)%ChunkSize-1;
        else blockPos.z = blockPos.z&ChunkSize-1;
        return this.blocks[blockPos.x][blockPos.y][blockPos.z] > 0;
    }

    /**
        Sets block in chunk
    */
    void setBlockAt(WorldPos blockPos, uint block) {
        if (blockPos.x < 0) blockPos.x = abs(blockPos.x)%ChunkSize-1;
        else blockPos.x = blockPos.x&ChunkSize-1;
        if (blockPos.y < 0) blockPos.y = abs(blockPos.y)%ChunkSize-1;
        else blockPos.y = blockPos.y&ChunkSize-1;
        if (blockPos.z < 0) blockPos.z = abs(blockPos.z)%ChunkSize-1;
        else blockPos.z = blockPos.z&ChunkSize-1;

        this.blocks[blockPos.x][blockPos.y][blockPos.z] = block;
        this.invalidateMesh();
    }

    /**
        Gets chunk over

        Returns null if chunk isn't found
    */
    Chunk chunkTop() {
        return world.getChunkAt(WorldPos(position.x, position.y+1, position.z));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkBottom() {
        return world.getChunkAt(WorldPos(position.x, position.y-1, position.z));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkFront() {
        return world.getChunkAt(WorldPos(position.x, position.y, position.z+1));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkBack() {
        return world.getChunkAt(WorldPos(position.x, position.y, position.z-1));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkLeft() {
        return world.getChunkAt(WorldPos(position.x-1, position.y, position.z));
    }

    /**
        Gets chunk under

        Returns null if chunk isn't found
    */
    Chunk chunkRight() {
        return world.getChunkAt(WorldPos(position.x+1, position.y, position.z));
    }

    World getWorld() {
        return world;
    }
}