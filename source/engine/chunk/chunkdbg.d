module engine.chunk.chunkdbg;
import engine.render;

private {
    GLuint vao;
    GLuint vbo;
    GLint mvp;
    Shader selectShader;
    size_t chunkBordersLen;
}

/**
    Initializes block selection
*/
void fcInitChunkDbg() {
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    selectShader = new Shader(import("sel.vert"), import("sel.frag"));
    mvp = selectShader.getUniformLocation("mvp");

    float[] chunkBorders = [

        // 0, 0
        0, 0,                   0,
        0, ChunkHeight,         0,

        // 1, 0
        ChunkSize, 0,           0,
        ChunkSize, ChunkHeight, 0,

        // 0, 1
        0, 0,           ChunkSize,
        0, ChunkHeight, ChunkSize,

        // 1, 1
        ChunkSize, 0,           ChunkSize,
        ChunkSize, ChunkHeight, ChunkSize,
    ];

    chunkBordersLen = chunkBorders.length;

    // I know this is bad but that keeps the model above easier to read.
    foreach(i; 0..chunkBorders.length) {
    }
    
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, float.sizeof*chunkBorders.length, chunkBorders.ptr, GL_STATIC_DRAW);
}

/**
    Draws block selection at specified coordinates
*/
void fcDrawChunkBorder(ChunkPos position) {
    glBindVertexArray(vao);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glEnable(GL_CULL_FACE);

    glLineWidth(6);

    selectShader.use();
    selectShader.setUniform(
        mvp, 
        FcCamera.getMatrix()*
        mat4.translation(
            cast(float)position.x*ChunkSize,
            0, 
            cast(float)position.z*ChunkSize
        )
    );

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);
    glDrawArrays(GL_LINES, 0, cast(int)chunkBordersLen/3);
    glDisableVertexAttribArray(0);
}