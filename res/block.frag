#version 330
in vec2 texUVs;
in float lightValue;
out vec4 outColor;

uniform sampler2D tex;

void main() {
    outColor = texture(tex, texUVs) * vec4(lightValue, lightValue, lightValue, 1);
}