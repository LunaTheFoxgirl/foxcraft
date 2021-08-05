module engine.block.blocksel;
import engine.render;

private {
    GLuint vao;
    GLuint vbo;
    GLint mvp;
    Shader selectShader;
    size_t blockSelAreaLen;
}

/**
    Initializes block selection
*/
void fcInitBlockSelect() {
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    selectShader = new Shader(import("sel.vert"), import("sel.frag"));
    mvp = selectShader.getUniformLocation("mvp");

    float[] blockSelArea = [

        // Top
        0, 1, 0,
        0, 1, 1,
        0, 1, 1,
        1, 1, 1,
        1, 1, 1,
        1, 1, 0,
        1, 1, 0,
        0, 1, 0,

        // Bottom
        0, 0, 0,
        0, 0, 1,
        0, 0, 1,
        1, 0, 1,
        1, 0, 1,
        1, 0, 0,
        1, 0, 0,
        0, 0, 0,

        // Left
        0, 1, 0,
        0, 1, 1,
        0, 1, 1,
        0, 0, 1,
        0, 0, 1,
        0, 0, 0,
        0, 0, 0,
        0, 1, 0,

        // Right
        1, 1, 0,
        1, 1, 1,
        1, 1, 1,
        1, 0, 1,
        1, 0, 1,
        1, 0, 0,
        1, 0, 0,
        1, 1, 0,

        // Front
        0, 1, 1,
        0, 0, 1,
        0, 0, 1,
        1, 0, 1,
        1, 0, 1,
        1, 1, 1,
        1, 1, 1,
        0, 1, 1,

        // Back
        0, 1, 0,
        0, 0, 0,
        0, 0, 0,
        1, 0, 0,
        1, 0, 0,
        1, 1, 0,
        1, 1, 0,
        0, 1, 0,
    ];

    blockSelAreaLen = blockSelArea.length;

    // I know this is bad but that keeps the model above easier to read.
    foreach(i; 0..blockSelArea.length) {
        blockSelArea[i] -= 0.5f;
    }
    
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, float.sizeof*blockSelArea.length, blockSelArea.ptr, GL_STATIC_DRAW);
}

/**
    Draws block selection at specified coordinates
*/
void fcDrawBlockSelection(WorldPos position) {
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
            cast(float)position.x+0.5f, 
            cast(float)position.y+0.5f, 
            cast(float)position.z+0.5f
        )*
        mat4.scaling(1.025, 1.025, 1.025)
    );

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, null);
    glDrawArrays(GL_LINES, 0, cast(int)blockSelAreaLen/3);
    glDisableVertexAttribArray(0);
}