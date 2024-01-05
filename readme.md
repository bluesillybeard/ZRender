# ZRender

ZRender is a cross platform 2D depthless rendering system written in Zig.


What is the purpose of ZRender?
- To be a simple but powerful rendering system that I can use for my projects. It's primary target (for now) is for my game Celestial, but I want it to be useful for other things.

What are the design goals of ZRender?
1. Take advantage of Zig's strengths
    - interfacing with C
    - compile time metaprogramming
    - cross-compilation
    - custom allocators
2. Focus on rendering
    - this isn't a game engine or toolkit, it's a rendering library.
    - However, it's also not just a basic GPU abstraction, there are lots of rendering-related utilities (as well as a custom animated vector graphics format)
3. Self contained
    - doesn't require external tools to be usable (Monogame's content system can die in a hole for all I care)
    - obviously dependencies (like OpenGl or SDL2) don't count
    - also software to create assets (image editors and such) don't count
4. Super simple 'hello world' and easy transition to more advanced features
    - Such as ImGUI where a single line of code can render a debug window for testing.
    - like OpenGL but with less legacy bloat and hackery

The usage of the API:
- create an instance
- create window(s)
- create draw list
    - Literally just a list of draw objects.
- create draw object(s)
    - Note that in order to create draw objects, a window must have been created first. This is because OpenGL is freaking stupid and requires a window.
        - This is not true for the Vulkan backend. unfortunately the Vulkan backend does not exist yet.
- each frame
    - fill the queue(s) with objects to draw
    - submit queue(s) to the window(s)
    - present windows
    - creating windows, draw queues, and draw objects are allowed during frames
    - multiple draw queues can be run on one window
    - one draw queue can be used on multiple windows
    - a draw queue can be reused between frames.

A draw object is basically just a shader, and a list of meshes. The list is ordered so things are drawn in a certain order.
- Counterintuitively, the shader also contains the transform information. This is because it allows each shader to take its own form of transformation data, which might be annoying to users, but I believe the benefits outweight the drawbacks.

A mesh object is an opaque ID that references an actual object on the GPU
- For example, in the OpenGL backend, it is a refernce to an object that contains the vertex buffer object, an element buffer objects, buffer sizes, and some metadata.
    - the vertex array object is actually part of a shader object (which is not directly exposed for users to interact with), since that is what's used to create the binding from vertex data to shader inputs.

A shader is actually a tagged union, where each field is a shader type. This limits what shaders are able to do, but since I control the entire stack anyways if I really need a custom shader I can just create a new field and implement it into each backend.

Supported platforms:
- Windows (untested at the moment)
- Linux & Steamdeck
- Macos probably I guess

Platforms I want to support in the future:
- Andriod
- IOS
- BSD
- Solaris maybe?

Platforms I want to support in the far future:
- Playstation 4, 5, maybe PS3???
- XBox
- Nintendo switch
- any other modern-ish game consoles
- WebGL
- WebGPU

Features I want to have:
- platform independent API (not at compile time, but at runtime)
    - OpenGL
        - OpenGL 4.1 for legacy hardware (aka macos lol)
        - OpenGL 4.6, if it ends up having features I can take advantage of
    - Vulkan
        - Vulkan 1.0
        - Vulkan 1.3, if it has good enough features to warrant it
    - Metal
        - The only reason I will support Metal is because it's the only "correct" way to support macos
    - I'm not going to do DirectX because Vulkan exists
- ability to retrieve platform-specific handles for users who need to use native APIS for any reason
- custom file loading through callbacks (defaults to normal file syste, obvs)
- easy multiwindowing (no need to deal with context switching or threading, just call functions on the window object)
- state is entirely managed in objects
- queue based rendering
- support for as many asset formats as possible (as well as custom ones for maximum efficiency)
- dynamically modifying loaded assets at runtime

Runtime dependencies:
- SDL2 (It also needs to be available at compile time so the executable can be linked against it)
- Either Vulkan or OpenGL 4.1
Compile time dependencies
- Zig 0.12.0-dev.1819+5c1428ea9 (doesn't need to be in path, just used to run the build.zig)
