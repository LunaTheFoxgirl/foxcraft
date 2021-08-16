#version 330
in vec2 texUVs;
in float lightValue;
out vec4 outColor;

uniform sampler2D tex;

void main() {
    
    // Discard fully transparent pixels
    if (texture(tex, texUVs).a == 0) discard;

    // Draw otherwise
    outColor = texture(tex, texUVs) * vec4(lightValue, lightValue, lightValue, 1);
}