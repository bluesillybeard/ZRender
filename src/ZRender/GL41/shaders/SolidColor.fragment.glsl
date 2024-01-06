#version 410

flat in vec4 _color;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = _color;
}