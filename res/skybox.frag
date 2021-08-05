#version 330
out vec4 outColor;

uniform sampler2D tex;

const vec3[] middayGradient = [
    vec3(0.0, 0.0, 1.0)
];

void main() {
    //outColor = texture(tex, texUVs) * vec4(lightValue, lightValue, lightValue, 1);
}