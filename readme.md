# ZRender - Official rendering module for [ZEngine](https://github.com/bluesillybeard/ZEngine)

THIS PROJECT IS ABANDONED. You can use any rendering library you want with ZEngine, so there really isn't reason for this to exist.

Currently, it is extremely simple - a draw component is simply these things:
- Handle to a 3D mesh
- Handle to a shader pipeline
- Uniform variables

## Accepted mesh formats
- None. Right now, a mesh is created by calling a function with the raw mesh data. Loading meshes from a file will be supported later

## Accepted texture formats
- png

## Matrix transforms
You're on your own in this regard. [zlm](https://github.com/ziglibs/zlm) is a good option for doing linear mathematics.

## Examples
For examples, see [ZEngineExamples](https://github.com/bluesillybeard/ZEngineExamples).

## TODO
- Get cross-compilation working
- compiling shaders at runtime?
- look into ditching Kinc and writing a custom renderer
    - Vulkan first
    - Look at porting libs instead of writing renderers for every API:
        - MoltenVK (Metal)
        - Ashes (DX9-DX11 and OpenGL)
        - Microsoft Dozen (DX12)
    - still allow for it to determine the used API at runtime
        - I don't believe there is an implementation of Vulkan that runs on top of WebGPU
        - The reason for doing it at runtime is so that a single binary can work on any computer ranging from old garbage that only supports OpenGL to a modern beast that can use Vulkan
- add immediate mode rendering options instead of forcing everything to be in the ECS
