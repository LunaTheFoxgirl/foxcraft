#version 330

uniform mat4 mvp;
layout(location = 0) in vec3 vrt;

void main() {
    gl_Position = mvp * vec4(vrt.x, vrt.y, vrt.z, 1);
}