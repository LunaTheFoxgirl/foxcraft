module engine.render.texture;
import std.exception;
import std.format;
import bindbc.opengl;
import imagefmt;
import engine;

/**
    Filtering mode for texture
*/
enum Filtering {
    /**
        Linear filtering will try to smooth out textures
    */
    Linear = GL_LINEAR,

    /**
        Point filtering will try to preserve pixel edges.
        Due to texture sampling being float based this is imprecise.
    */
    Point = GL_NEAREST
}

/**
    Texture wrapping modes
*/
enum Wrapping {
    /**
        Clamp texture sampling to be within the texture
    */
    Clamp = GL_CLAMP_TO_BORDER,

    /**
        Wrap the texture in every direction idefinitely
    */
    Repeat = GL_REPEAT,

    /**
        Wrap the texture mirrored in every direction indefinitely
    */
    Mirror = GL_MIRRORED_REPEAT
}

/**
    A texture which is not bound to an OpenGL context
    Used for texture atlassing
*/
struct ShallowTexture {
public:
    /**
        8-bit RGBA color data
    */
    ubyte[] data;

    /**
        Width of texture
    */
    int width;

    /**
        Height of texture
    */
    int height;

    /**
        Loads a shallow texture from image file
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(string file) {

        // Load image from disk, as RGBA 8-bit
        IFImage image = read_image(file, 4, 8);
        enforce( image.e == 0, "%s: %s".format(IF_ERROR[image.e], file));
        scope(exit) image.free();

        // Copy data from IFImage to this ShallowTexture
        this.data = new ubyte[image.buf8.length];
        this.data[] = image.buf8;

        // Set the width/height data
        this.width = image.w;
        this.height = image.h;
    }

    /**
        Loads a shallow texture from image buffer
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(ubyte[] buffer) {

        // Load image from disk, as RGBA 8-bit
        IFImage image = read_image(buffer, 4, 8);
        enforce( image.e == 0, "%s".format(IF_ERROR[image.e]));
        scope(exit) image.free();

        // Copy data from IFImage to this ShallowTexture
        this.data = new ubyte[image.buf8.length];
        this.data[] = image.buf8;

        // Set the width/height data
        this.width = image.w;
        this.height = image.h;
    }

    /**
        Saves image
    */
    void save(string file) {
        write_image(file, this.width, this.height, this.data, 4);
    }

    /**
        Gets whether the image is transparent
    */
    bool isTransparent() {
        foreach(i; 0..data.length/4) {
            if (data[3+(i*4)] < 255) return true;
        }
        return false;
    }
}

/**
    A texture, only format supported is unsigned 8 bit RGBA
*/
class Texture {
private:
    GLuint id;
    int width_;
    int height_;
    bool hasTransparency_;

    GLuint colorMode;
    int alignment;

    bool scanTransparency(ubyte[] data) {
        foreach(i; 0..data.length/4) {
            if (data[i*4] < 255) return true;
        }
        return false;
    }

public:

    /**
        Loads texture from image file
        Supported file types:
        * PNG 8-bit
        * BMP 8-bit
        * TGA 8-bit non-palleted
        * JPEG baseline
    */
    this(string file) {

        // Load image from disk, as RGBA 8-bit
        IFImage image = read_image(file, 4, 8);
        enforce( image.e == 0, "%s: %s".format(IF_ERROR[image.e], file));
        scope(exit) image.free();

        // Load in image data to OpenGL
        this(image.buf8, image.w, image.h);
    }

    /**
        Creates a texture from a ShallowTexture
    */
    this(ShallowTexture shallow) {
        this(shallow.data, shallow.width, shallow.height);
    }

    /**
        Creates a new empty texture
    */
    this(int width, int height, GLuint mode = GL_RGBA, int alignment = 4) {

        // Create an empty texture array with no data
        ubyte[] empty = new ubyte[width_*height_*alignment];

        // Pass it on to the other texturing
        this(empty, width, height, mode, alignment);
    }

    /**
        Creates a new texture from specified data
    */
    this(ubyte[] data, int width, int height, GLuint mode = GL_RGBA, int alignment = 4) {
        this.colorMode = mode;
        this.alignment = alignment;
        this.width_ = width;
        this.height_ = height;
        
        // Generate OpenGL texture
        glGenTextures(1, &id);
        this.setData(data);
        
        if (mode == GL_RGBA) this.hasTransparency_ = this.scanTransparency(data);
        else this.hasTransparency_ = false;

        // Set default filtering and wrapping
        this.setFiltering(Filtering.Point);
        this.setWrapping(Wrapping.Mirror);
    }

    /**
        Width of texture
    */
    int width() {
        return width_;
    }

    /**
        Height of texture
    */
    int height() {
        return height_;
    }

    /**
        Center of texture
    */
    vec2i center() {
        return vec2i(width_/2, height_/2);
    }

    /**
        Gets the size of the texture
    */
    vec2i size() {
        return vec2i(width_, height_);
    }

    /**
        Set the filtering mode used for the texture
    */
    void setFiltering(Filtering filtering) {
        this.bind();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filtering);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filtering);
    }

    /**
        Set the wrapping mode used for the texture
    */
    void setWrapping(Wrapping wrapping) {
        this.bind();
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapping);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapping);
        
        glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, [0f, 0f, 0f, 0f].ptr);
    }

    /**
        Sets the data of the texture
    */
    void setData(ubyte[] data) {
        this.bind();
        glPixelStorei(GL_UNPACK_ALIGNMENT, alignment);
        glTexImage2D(GL_TEXTURE_2D, 0, colorMode, width_, height_, 0, GL_RGBA, GL_UNSIGNED_BYTE, data.ptr);
        glGenerateMipmap(GL_TEXTURE_2D);
        
        if (colorMode == GL_RGBA) this.hasTransparency_ = this.scanTransparency(data);
        else this.hasTransparency_ = false;
    }

    /**
        Sets a region of a texture to new data
    */
    void setDataRegion(ubyte[] data, int x, int y, int width, int height) {
        this.bind();

        // Make sure we don't try to change the texture in an out of bounds area.
        enforce( x >= 0 && x+width <= this.width_, "x offset is out of bounds (xoffset=%s, xbound=%s)".format(x+width, this.width_));
        enforce( y >= 0 && y+height <= this.height_, "y offset is out of bounds (yoffset=%s, ybound=%s)".format(y+height, this.height_));

        // Update the texture
        glPixelStorei(GL_UNPACK_ALIGNMENT, alignment);
        glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, width, height, this.colorMode, GL_UNSIGNED_BYTE, data.ptr);
        glGenerateMipmap(GL_TEXTURE_2D);
        
        if (colorMode == GL_RGBA) this.hasTransparency_ = this.scanTransparency(data);
        else this.hasTransparency_ = false;
    }

    /**
        Bind this texture
        
        Notes
        - In release mode the unit value is clamped to 31 (The max OpenGL texture unit value)
        - In debug mode unit values over 31 will assert.
    */
    void bind(uint unit = 0) {
        assert(unit <= 31u, "Outside maximum OpenGL texture unit value");
        glActiveTexture(GL_TEXTURE0+(unit <= 31u ? unit : 31u));
        glBindTexture(GL_TEXTURE_2D, id);
    }

    /**
        Saves the texture to file
    */
    void save(string file) {
        write_image(file, width, height, getTextureData(), 4);
    }

    /**
        Gets the texture data for the texture
    */
    ubyte[] getTextureData() {
        ubyte[] buf = new ubyte[width*height*4];
        bind();
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, buf.ptr);
        return buf;
    }

    /**
        Gets this texture's texture id
    */
    GLuint getTextureId() {
        return id;
    }

    /**
        Gets whether the texture has transparency
    */
    bool hasTransparency() {
        return hasTransparency_;
    }
}

private {
    Texture[] textureBindings;
    bool started = false;
}

/**
    Begins a texture loading pass
*/
void inBeginTextureLoading() {
    enforce(!started, "Texture loading pass already started!");
    started = true;
}

/**
    Returns a texture from the internal texture list
*/
Texture inGetTextureFromId(uint id) {
    enforce(started, "Texture loading pass not started!");
    return textureBindings[cast(size_t)id];
}

/**
    Gets the latest texture from the internal texture list
*/
Texture inGetLatestTexture() {
    return textureBindings[$-1];
}

/**
    Adds binary texture
*/
void inAddTextureBinary(ShallowTexture data) {
    textureBindings ~= new Texture(data);
}

/**
    Ends a texture loading pass
*/
void inEndTextureLoading() {
    enforce(started, "Texture loading pass not started!");
    started = false;
    textureBindings.length = 0;
}