#!/bin/bash

# TODO: figure out how to support both Vulkan and OpenGL.
# This article may help: https://community.arm.com/arm-community-blogs/b/graphics-gaming-and-vr-blog/posts/spirv-cross-working-with-spir-v-in-your-app
# It also might be possible to take the OpenGL SPIRV binary and make it compatible with Vulkan.
fragmentOptions="--target-env opengl -S frag"
vertexOptions="--target-env opengl -S vert"

# TODO: use a for loop instead of this insanity
glslangValidator 4_shader.vert.glsl $vertexOptions -o bin/4_shader.vert.spv
glslangValidator 4_shader.frag.glsl $fragmentOptions -o bin/4_shader.frag.spv

glslangValidator 7_uniforms.vert.glsl $vertexOptions -o bin/7_uniforms.vert.spv
glslangValidator 7_uniforms.frag.glsl $fragmentOptions -o bin/7_uniforms.frag.spv

# TODO: use a for loop instead of this insanity

shader_embeds="
// This file is added as a module for all of the examples\n\
pub const @\"4_shader.vert.spv\" = @embedFile(\"4_shader.vert.spv\");\n\
pub const @\"4_shader.frag.spv\" = @embedFile(\"4_shader.frag.spv\");\n\
pub const @\"7_uniforms.vert.spv\" = @embedFile(\"7_uniforms.vert.spv\");\n\
pub const @\"7_uniforms.frag.spv\" = @embedFile(\"7_uniforms.frag.spv\");\n\
"

echo -e $shader_embeds > bin/shader_embeds.zig
