#version 450

// ZRender supports most SPIRV binaries,
// However I find it easiest to use glslangValidator to compile GLSL code.

// This is sent in from a mesh object
layout(location = 0) in vec2 pos;
layout(location = 1) in vec3 color;

// This will be sent to the fragment shader. It's not marked as flat, so it will be linearly interpolated between vertices.
layout(location = 0) out vec3 fragColor;

void main() {
    // GLSL was originally made for OpenGL, so that's why the "legacy" gl_Position variable is used for the output,
    // Even though this shader could theoretically run in any backend (such as Vulkan or Metal)
    gl_Position = vec4(pos, 0.0, 1.0);
    fragColor = color;
}