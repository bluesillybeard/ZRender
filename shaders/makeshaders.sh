fragmentOptions="--target-env opengl --target-env vulkan1.0 -S frag"
vertexOptions="--target-env opengl --target-env vulkan1.0 -S frag"

glslangValidator 3_mesh.vert.glsl $fragmentOptions -o bin/3_mesh.vert.spv
glslangValidator 3_mesh.frag.glsl $vertexOptionsl -o bin/3_mesh.frag.spv
