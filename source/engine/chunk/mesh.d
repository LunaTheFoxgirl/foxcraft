module engine.chunk.mesh;
import engine.chunk;
import core.thread;
import core.sync.mutex;
import core.atomic;
import engine.render;
import std.math : cmp;
import engine.utils.threadpool;

//
// Chunk Rendering
//

private {
    GLuint chunkVAO;
    Shader blockShader;
    GLint mvp;
    GLint chunkPosition;
    GLint cameraPosition;
}

/**
    Chunk Mesh Data
*/
struct CMData {
    vec3 vertex; /// Vertices
    vec2 uv; /// UV Coordinates
    //float vts; /// Vertex Texture Size
    float light; /// Light value at face
}

/**
    A mesher which generates meshes for a chunk
*/
class ChunkVertexBuffer {
public:

    /**
        amount of elements in buffer
    */
    size_t count;

    /**
        The VBO
    */
    GLuint vbo;

    ~this() {
        //import std.stdio;
        //writeln("Deleting buffer ", vbo, "...");
        glDeleteBuffers(1, &vbo);
        vbo = 0;
    }

    /**
        Constructs a vertex buffer
    */
    this() {    
        glGenBuffers(1, &vbo);
    }

    /**
        Upload vertex data to the GPU
    */
    void upload(immutable(CMData[]) data) {
        if (data is null) {
            count = 0;
            return;
        }
        atomicStore(count, data.length);

        // No need to upload empty buffers.
        if (count == 0) return;
        if (vbo == 0) return;

        glBindVertexArray(chunkVAO);
        glBindBuffer(GL_ARRAY_BUFFER, this.vbo);
        glBufferData(GL_ARRAY_BUFFER, CMData.sizeof*data.length, data.ptr, GL_DYNAMIC_DRAW);
    }

    size_t length() {
        return atomicLoad(count);
    }
}

/**
    Initialize rendering for Chunk Meshes
*/
void fcInitChunkMeshRender() {
    glGenVertexArrays(1, &chunkVAO);
    blockShader = new Shader(import("block.vert"), import("block.frag"));
    mvp = blockShader.getUniformLocation("mvp");
    chunkPosition = blockShader.getUniformLocation("chunkPosition");
    cameraPosition = blockShader.getUniformLocation("cameraPosition");
}

/**
    The mesh of a chunk, gets periodically regenerated
*/
class ChunkMesh {
public:
    Chunk chunk;
    ChunkVertexBuffer buffer;
    ChunkVertexBuffer trbuffer;

    this(Chunk chunk) {
        this.chunk = chunk;
        this.buffer = new ChunkVertexBuffer();
        this.trbuffer = new ChunkVertexBuffer();
    }

    /**
        Regenerates the mesh

        TODO: use a better meshing method
    */
    void regenerate(bool highPriority = false) {
        MeshGenerator.enqueue(new immutable(MeshGenTask)(
            cast(immutable(ChunkVertexBuffer)*)&buffer, 
            cast(immutable(ChunkVertexBuffer)*)&trbuffer, 
            cast(immutable(CMView))CMView(chunk)
        ), highPriority);
    }

    /**
        Draws the chunk mesh
    */
    void draw() {
        size_t len = buffer.length;
        if (len == 0) return;
        if (buffer.vbo == 0) return;

        glBindVertexArray(chunkVAO);

        glEnable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  

        blockShader.use();
        blockShader.setUniform(mvp, 
            FcCamera.getMatrix() * 
            mat4.translation(chunk.worldPosition)
        );
        
        blockShader.setUniform(chunkPosition, chunk.worldPosition);
        blockShader.setUniform(cameraPosition, FcCamera.worldPosition);

        fcAtlasBind();

        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glEnableVertexAttribArray(2);

        glBindBuffer(GL_ARRAY_BUFFER, buffer.vbo);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, CMData.sizeof, null);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, CMData.sizeof, cast(void*)CMData.uv.offsetof);
        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, CMData.sizeof, cast(void*)CMData.light.offsetof);
        //glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, CMData.sizeof, cast(void*)CMData.vts.offsetof);

        glDrawArrays(GL_TRIANGLES, 0, cast(int)len);

        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(2);

    }

    /**
        Draws the transparent parts of the chunk mesh
    */
    void drawtr() {
        size_t len = trbuffer.length;
        if (len == 0) return;
        if (trbuffer.vbo == 0) return;

        glBindVertexArray(chunkVAO);

        glEnable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glEnable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);  

        blockShader.use();
        blockShader.setUniform(mvp, 
            FcCamera.getMatrix() * 
            mat4.translation(chunk.worldPosition)
        );
        
        blockShader.setUniform(chunkPosition, chunk.worldPosition);
        blockShader.setUniform(cameraPosition, FcCamera.worldPosition);

        fcAtlasBind();

        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glEnableVertexAttribArray(2);

        glBindBuffer(GL_ARRAY_BUFFER, trbuffer.vbo);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, CMData.sizeof, null);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, CMData.sizeof, cast(void*)CMData.uv.offsetof);
        glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, CMData.sizeof, cast(void*)CMData.light.offsetof);
        //glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, CMData.sizeof, cast(void*)CMData.vts.offsetof);

        glDrawArrays(GL_TRIANGLES, 0, cast(int)len);

        glDisableVertexAttribArray(0);
        glDisableVertexAttribArray(1);
        glDisableVertexAttribArray(2);

    }
}