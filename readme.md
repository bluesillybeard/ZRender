# ZRender

ZRender is a cross platform rendering system written in Zig.

What is the purpose of ZRender?
- To be a simple but powerful rendering system that I can use for my projects. It's primary target (for now) is for my game Celestial, but I want it to be useful for other things.

What are the design goals of ZRender?
1. Take advantage of Zig's strengths
    - interfacing with C
    - compile time metaprogramming
    - cross-compilation
    - custom allocators
2. Intuitive cross platform low-level API
    - Something similar to GLFW+OpenGL, but with less tedium and easier to use
    - sensible defaults to make it easier, but that can be highly configured for advanced usecases
3. Focus on rendering
    - this isn't a game engine or toolkit, it's a rendering library.
4. Self contained
    - doesn't require external tools to work (Monogame's content system can die in a hole for all I care)
    - obviously dependencies (like OpenGl or GLFW) don't count
    - One exception is for compiling shaders to SPIRV binaries - However, that is a standard practice among many rendering libraries so it's not a big deal
5. Super simple 'hello world' and easy transition to more advanced features
    - Such as ImGUI where a single line of code can render a debug window for testing.
    - like OpenGL but with less legacy bloat and hackery

Supported platforms:
- Windows (untested at the moment)
- Linux & Steamdeck
- Macos probably

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
    - ability to use the native handle to create a ZRender object
- custom file loading through callbacks (defaults to normal file syste, obvs)
- GLSL shaders (Only Vertex and Pixel shaders, for compatibility and performance)
- easy multiwindowing (no need to deal with context switching or threading, just call functions on the window object)
- multithreading but also fast single threaded performance
- state is entirely managed in objects - nothing static at all (other than that STUPID OpenGL context)
- queue based rendering
- (very unlikely to be realistically doable) use native APIS as much as possible instead of GLFW
- ZRender is in charge of timing through the use of callbacks and events
- support for as many asset formats as possible (as well as custom ones for maximum efficiency)
- dynamically modifying loaded assets at runtime
- GPU accelerated computing

Plan (for each step, make an example or two):
- ~~Get the minimal example "working"~~
- ~~timing callbacks~~
- ~~render queue (well, start it anyway - its only command for now will be to clear the screen to a color)~~
- ~~multiple windows~~
- ~~meshes (don't forget to keep track of attributes and the mesh type) (only support triangles and quads for now)~~
    - note: Many methods still need to be actually implemented on the OpenGL 4.1 backend
- ~~shaders (Only support SPIR-V binaries to make supporting both OpenGL and Vulkan easier)~~
    - shader uniforms
- textures (should be pretty easy)
- loading assets
- modifying loaded assets
    - At this point in the plan, VRender should have a similar set of features as VRender.
- Do a whole bunch of cleanup
    - make the API consistent and add any potentially missing features
    - make a bunch of tests to hopefully verify every feature
    - comment the absolute living bananas out of the code base (within reason of course)
        - Use common sense, some places don't need a comment, and try to keep them consice and informative
- implement the Vulkan API
    - use Vulkan 1.0 since later versions of Vulkan don't add many features that would be useful to me
- Make sure all of the tests work the same with both Vulkan and OpenGL
    - Make some more tests to really probe for any signifivant behavior differences between the OpenGL and Vulkan implementations
        - Try to include various shaders of various to make sure the SPIR-V binaries work the same
            - if they don't work the same, find as many compatibility problems as possible and document them

Other things that should be done:
- make sure everything is consistent (Zig style guidelines, except variables and such use camelCase because pascal_case is super annoying to type in my opinion.)
    - If people complain, switch everything to use the actual zig style guidelines instead of my modified version
- use "grep -rnI TODO" to find todos and complete them
- rewrite this readme before the library goes public


Runtime dependencies:
- SDL2 (It also needs to be available at compile time so the executable can be linked against it)
- Either Vulkan or OpenGL 4.1 with the ARB_gl_spirv extension
    - note: I might add support for bindless textures at some point, but it will not be required unless its support is virtually 100%
Compile time dependencies
- Zig 0.12.0-dev.1819+5c1428ea9 (doesn't need to be in path, just used to run the build.zig)
- glslangValidator in path (Part of the [Vulkan SDK](https://vulkan.lunarg.com/sdk/home))
