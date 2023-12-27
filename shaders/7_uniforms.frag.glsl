#version 450

// ZRender supports most SPIRV binaries,
// However I find it easiest to use glslangValidator to compile GLSL code.

// This variable is taken in from the vertex shader. It's not marked as flat, so it will be linearly interpolated between vertices.
layout(location = 0) in vec3 fragColor;

// This is the color output for the shader. It will be written to the framebuffer.
// I don't really know how the compiler finds which output is supposed to be the one for the framebuffer,
// but reguardless it dos end up finding it, and when the shader is done running its value will be written to the framebuffer.
layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(fragColor, 1.0);
}