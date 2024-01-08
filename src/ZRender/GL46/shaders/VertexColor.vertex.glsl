#version 460

layout(location = 1) uniform mat3 transform;

layout(location = 0) in vec2 pos;
layout(location = 1) in vec4 color;

out vec4 _color;

void main() {
    _color = color;
    gl_Position = vec4(vec3(pos, 1) * transform, 1);
}