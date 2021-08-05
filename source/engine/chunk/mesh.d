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
    Container for CMData vertices
*/
struct CMDataArr {
    /**
        The vertices of the buffer
    */
    CMData[] vertices;
}

/**
    A mesher which generates meshes for a chunk
*/
class ChunkVertexBuffer {
public:

    /**
        The vertices in this buffer
    */
    immutable(CMDataArr)* data;

    /**
        The VBO
    */
    GLuint vbo;

    /**
        Constructs a vertex buffer
    */
    this() {    
        glGenBuffers(1, &vbo);
    }
    

    /**
        Pass an immutable vertex data buffer to this buffer, swapping it
    */
    void pass(immutable(CMDataArr)* data) {
        atomicExchange(&this.data, data);
    }

    /**
        Upload vertex data to the GPU
    */
    void upload() {
        if (data is null) return;
        auto idata = atomicLoad(data);

        // No need to upload empty buffers.
        if (idata.vertices.length == 0) return;

        glBindVertexArray(chunkVAO);
        glBindBuffer(GL_ARRAY_BUFFER, this.vbo);
        glBufferData(GL_ARRAY_BUFFER, CMData.sizeof*idata.vertices.length, idata.vertices.ptr, GL_DYNAMIC_DRAW);
    }

    size_t length() {
        auto idata = atomicLoad(data);
        return idata !is null ? idata.vertices.length : 0;
    }

    override
    string toString() {
        import std.format : format;
        string mstr = "";
        foreach(CMData data; data.vertices) {
            mstr ~= "v %f %f %f\n".format(data.vertex.x, data.vertex.y, data.vertex.z);
        }
        return mstr;
    }
}

/**
    Initialize rendering for Chunk Meshes
*/
void fcInitChunkMeshRender() {
    glGenVertexArrays(1, &chunkVAO);
    blockShader = new Shader(import("block.vert"), import("block.frag"));
    mvp = blockShader.getUniformLocation("mvp");
}

/**
    The mesh of a chunk, gets periodically regenerated
*/
class ChunkMesh {
public:
    Chunk chunk;
    ChunkVertexBuffer buffer;

    this(Chunk chunk) {
        this.chunk = chunk;
        this.buffer = new ChunkVertexBuffer();
    }

    /**
        Regenerates the mesh

        TODO: use a better meshing method
    */
    void regenerate() {
        MeshGenerator.enqueue(new immutable(MeshGenTask)(
            cast(immutable(ChunkMesh))this, 
            cast(immutable(CMView))CMView(chunk)
        ));
    }

    /**
        Draws the chunk mesh
    */
    void draw() {
        size_t len = buffer.length;
        if (len == 0) return;

        glBindVertexArray(chunkVAO);

        glEnable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glEnable(GL_CULL_FACE);

        blockShader.use();
        blockShader.setUniform(mvp, 
            FcCamera.getMatrix()*
            mat4.translation(
                chunk.position.x*ChunkSize, 
                chunk.position.y*ChunkSize, 
                chunk.position.z*ChunkSize
            )
        );

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
}