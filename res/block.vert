#version 330
uniform mat4 mvp;
uniform vec3 chunkPosition;
uniform vec3 cameraPosition;
layout(location = 0) in vec3 vrt;
layout(location = 1) in vec2 uvs;
layout(location = 2) in float light;

out vec2 texUVs;
out float lightValue;

void main() {
    const float curvatureStart = 128.0; 
    const float curveDiv = 32.0; // should be 1024 for proper use

    float dist = distance(
        vec2(
            (chunkPosition.x+vrt.x),
            (chunkPosition.z+vrt.z)
        ),
        vec2(
            -cameraPosition.x,
            -cameraPosition.z
        )
    );

    float curvature = mix(
        0, 
        dist / curveDiv, 
        clamp(abs(dist)/curvatureStart, 0, curvatureStart)
    );


    gl_Position = mvp * vec4(vrt.x, vrt.y-curvature, vrt.z, 1);
    texUVs = uvs;
    lightValue = light;
}