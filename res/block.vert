#version 330
uniform mat4 mvp;
layout(location = 0) in vec3 vrt;
layout(location = 1) in vec2 uvs;
layout(location = 2) in float light;

out vec2 texUVs;
out float lightValue;

void main() {
    gl_Position = mvp * vec4(vrt.x, vrt.y, vrt.z, 1);
    texUVs = uvs;
    lightValue = light;
}