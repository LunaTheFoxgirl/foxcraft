module engine.block;
public import engine.render.atlas;
import engine;

/**
    A block reference
*/
alias BlockRef = uint;

/**
    A block
*/
class Block {
package(engine):
    /**
        The textures for each side of the block
    */
    string[6] textures;

    /**
        Name of the block
    */
    string name;

protected:
    
    /**
        Sets texture for all faces of the block
    */
    void setTexture(string texture) {
        fcAtlasAddTexture(texture);
        static foreach(i; 0..6) {
            textures[i] = texture;
        }
    }

    /**
        Sets the texture for each side of the block
        0 - Front
        1 - Back
        2 - Top
        3 - Bottom
        4 - Left
        5 - Right
    */
    void setTexturesSides(string[6] textureList) {
        static foreach(i; 0..6) {
            fcAtlasAddTexture(textureList[i]);
            textures[i] = textureList[i];
        }
    }

    /**
        Sets the name of the block
    */
    void setName(string name) {
        this.name = name;
    }

public:

    string getName() {
        return this.name;
    }

    /**
        Breaks block at specified location
    */
    void breakBlockAt(World worldIn, WorldPos pos) {
        if (Chunk chunk = worldIn.getChunkAt(pos)) chunk.setBlockAt(pos, 0);
    }
}

//
// Block Register
//

private {
    __gshared Block[uint] blocksInRegistry;
}

/**
    Registers a block in the block registry.

    ID 0 is reserved for AIR blocks
*/
void fcRegisterBlock(Block block, uint id) {
    blocksInRegistry[id] = block;
}

/**
    Gets block from the registry
*/
Block fcGetBlock(uint id) {
    return id in blocksInRegistry ? blocksInRegistry[id] : null;
}