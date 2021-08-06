module engine.block;
public import engine.render.atlas;
public import engine.block.blocksel;
import engine;

/**
    A block reference
*/
alias BlockRef = ushort;

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

    /**
        Human readable name
    */
    string displayName;

    /**
        ID of the block
    */
    BlockRef id;

protected:

    /**
        Collission for the block
    */
    AABB[] collission;
    
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

    /**
        Sets the default human-readable display name
    */
    void setDisplayName(string name) {
        this.displayName = name;
    }

    this() {
        this.collission = [AABB(vec3(0, 0, 0), vec3(1, 1, 1))];
    }

public:

    /**
        Sets the block's collission
    */
    void setCollission(AABB[] collission) {
        this.collission = collission;
    }

    /**
        Gets the name of the block
    */
    string getName() {
        return this.name;
    }

    /**
        Gets the human-readable display name of the block
    */
    string getDisplayName() {
        return this.displayName;
    }

    /**
        Gets the collission for the block
    */
    AABB[] getCollission() {
        return collission;
    }

    /**
        Gets the ID of the block
    */
    BlockRef getId() {
        return this.id;
    }
}

//
// Block Register
//

private {
    __gshared Block[BlockRef] blocksInRegistry;
    __gshared BlockRef[string] blockNamesInRegistry;
}

/**
    Registers a block in the block registry.

    ID 0 is reserved for AIR blocks
*/
void fcRegisterBlock(Block block, BlockRef id) {
    blocksInRegistry[id] = block;
    blockNamesInRegistry[block.name] = id;
}

/**
    Gets block from the registry
*/
Block fcGetBlock(BlockRef id) {
    return id in blocksInRegistry ? blocksInRegistry[id] : null;
}