# ZRender - Official rendering module for [ZEngine](https://github.com/bluesillybeard/ZEngine)

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
- look into ditching Kinc and writing a custom Vulkan renderer
    - Look porting libs:
        - MoltenVK (Metal)
        - Ashes (DX9-DX11 and OpenGL)
        - Microsoft Dozen (DX12)
