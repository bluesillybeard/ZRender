#!/bin/bash

fragmentOptions="--target-env opengl --target-env vulkan1.0 -S frag"
vertexOptions="--target-env opengl --target-env vulkan1.0 -S vert"

# TODO: use a for loop instead of this insanity
glslangValidator 4_shader.vert.glsl $vertexOptions -o bin/4_shader.vert.spv
glslangValidator 4_shader.frag.glsl $fragmentOptions -o bin/4_shader.frag.spv

# TODO: use a for loop instead of this insanity

shader_embeds="
// This file is added as a module for all of the examples\n\
pub const @\"4_shader.vert.spv\" = @embedFile(\"4_shader.vert.spv\");\n\
pub const @\"4_shader.frag.spv\" = @embedFile(\"4_shader.frag.spv\");\n\
"

echo -e $shader_embeds > bin/shader_embeds.zig
