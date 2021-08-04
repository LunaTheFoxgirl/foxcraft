module engine.render.atlas;
import engine.render.atlas.packer;
import engine;
import engine.render;
import core.sync.mutex;

/**
    Initializes the block and item atlas
*/
void fcInitAtlas() {
    uvStoreMutex = new Mutex();
    atlasTexture = new Texture(16_384, 16_384);
    packer = new TexturePacker(vec2i(16_384, 16_384));
}

private {
    TexturePacker packer;
    Texture atlasTexture;
    __gshared vec4[string] uvStore;
    __gshared Mutex uvStoreMutex;
}

/**
    Adds texture to atlas
*/
void fcAtlasAddTexture(string name) {

    // We already have that texture stored
    if (name in uvStore) return;
    
    // Load and pack the texture
    ShallowTexture tex = ShallowTexture("textures/"~name~".png");
    vec4i uvPixels = packer.packTexture(vec2i(tex.width, tex.height));

    // Set the region of the atlas for the texture
    atlasTexture.setDataRegion(
        tex.data, 
        uvPixels.x, 
        uvPixels.y,
        uvPixels.z, 
        uvPixels.w
    );

    uvStoreMutex.lock();
    uvStore[name] = vec4(
        cast(float)uvPixels.x/16_384f,
        cast(float)uvPixels.y/16_384f,
        cast(float)(uvPixels.x+uvPixels.z)/16_384f,
        cast(float)(uvPixels.y+uvPixels.w)/16_384f
    );
    uvStoreMutex.unlock();
}

/**
    Gets texture from atlas
*/
vec4 fcAtlasGet(string name) {
    uvStoreMutex.lock();
    scope(exit) uvStoreMutex.unlock();
    return uvStore[name];
}

/**
    Binds the atlas texture
*/
void fcAtlasBind() {
    atlasTexture.bind();
}