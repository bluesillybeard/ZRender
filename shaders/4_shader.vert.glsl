#version 450

// ZRender supports most SPIRV binaries,
// However I find it easiest to use glslangValidator to compile GLSL code.

// This will be sent to the fragment shader. It's not marked as flat, so it will be linearly interpolated between vertices.
layout(location = 0) out vec3 fragColor;

// This shader has no input; instead it assumes three vertices and bakes them into the shader itself.
vec2 positions[3] = vec2[](
    vec2(0.0, -0.5),
    vec2(0.5, 0.5),
    vec2(-0.5, 0.5)
);

vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void main() {
    // GLSL was originally made for OpenGL, so that's why the "legacy" gl_Position variable is used for the output,
    // Even though this shader could theoretically run in any backend (such as Vulkan or Metal)
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}