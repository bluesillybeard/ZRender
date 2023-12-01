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
4. Modular
    - components can be swapped in and out without too many links between pieces.
    - They don't have to be user-configurable for now because I'm only making this for myself.
5. Self contained
    - doesn't require external tools to work (Monogame's content system can die in a hole for all I care)
    - obviously dependencies (like OpenGl or GLFW) don't count
6. Super simple 'hello world' and easy transition to more advanced features
    - Such as ImGUI where a single line of code can render a debug window for testing.
    - like OpenGL but with less legacy bloat and hackery

Supported platforms:
- Windows (with GLFW) (untested at the moment)
- Linux & Steamdeck (with GLFW)

Platforms I want to support in the future:
- Macos (with GLFW)
- Andriod
- IOS
- BSD
- Solaris maybe?

Platforms I want to support in the far future:
- Playstation 4, 5, maybe PS3
- XBox
- Nintendo switch
- any other modern-ish game consoles
- WebGL (with GLFW and legacy OpenGL backend.)

Features I want to have:
- platform independent API (not at compile time, but at runtime)
    - OpenGL+native API (X11, WIN32, Cocoa, Wayland) (native API to make multiwindowing better since GLFW doesn't have good multiwindowing)
        - I might use GLFW for most of the work, then the native API for window switching.
        - OpenGL 3.3 for legacy hardware
        - OpenGL 4.6, if it ends up having features I can take advantage of
    - Vulkan + GLFW
        - the multiwinding issue is not present with Vulkan, since the Vulkan instance runs independent of windows
- ability to retrieve platform-specific handles for users who need to use native APIS for any reason
    - ability to use the native handle to create a ZRender object
- custom file loading through callbacks (defaults to normal file syste, obvs)
- GLSL shaders (Only Vertex and Pixel shaders, for compatibility and performance)
- easy multiwindowing (no need to deal with context switching or threading, just call functions on the window object)
    - On OpenGL+GLFW, access to the native API is required to switch the window without switching the OpenGL context.
- multithreading but also fast single threaded performance
- state is entirely managed in objects - nothing static at all
- queue based rendering
- (very unlikely to be realistically doable) use native APIS as much as possible instead of GLFW
- ZRender is in charge of timing through the use of callbacks and events (similar to how VRender works for Trilateral, but taken further like GTK)
- support for as many asset formats as possible (as well as custom ones for maximum efficiency)
- dynamically modifying loaded assets at runtime
- GPU accelerated computing

What I need to implement in order to start work on Celestial:
- platform independent API (not at compile time, but at runtime)
    - OpenGL+native API (X11, WIN32, Cocoa, Wayland) (native API to make multiwindowing better since GLFW doesn't have good multiwindowing)
        - I might use GLFW for most of the work, then the native API for window switching.
        - OpenGL 3.3 for legacy hardware
- easy multiwindowing (no need to deal with context switching or threading, just call functions on the window object)
    - On OpenGL+GLFW, access to the native API is required to switch the window without switching the OpenGL context.
- state is entirely managed in objects - nothing static at all
- queue based rendering
- ZRender is in charge of timing through the use of callbacks and events (similar to how VRender works for Trilateral, but taken further like in GTK)
- support for loading textures and meshes, the exact format is not important
- dynamically modifying loaded assets

Plan (for each step, make an example or two):
- ~~Get the minimal example "working"~~
- ~~timing callbacks~~
- ~~render queue (well, start it anyway - its only command for now will be to clear the screen to a color)~~
- ~~multiple windows~~
- meshes (don't forget to keep track of attributes and the mesh type) (only support triangles and quads for now)
- textures (should be pretty easy)
    - Zig supports SPIR-V as a compilation target. Wouldn't it be super cool to write shaders in Zig too? Zig all the way!
- shaders (Only support SPIR-V binaries to make supporting both OpenGL and Vulkan easier)
    - shaders are a bit complex, since they basically define an entire pipeline.
    - Since all sets of shaders will just be a pixel and vertex shader, only bother with that.
    - uniforms could get interesting but VRender's system is probably ok
- loading assets
- modifying loaded assets
    - At this point in the plan, VRender should have a similar set of features as VRender.
- Do a whole bunch of cleanup
    - make the API consistent and add any potentially missing features
    - make a bunch of tests to hopefully verify every feature
- implement the Vulkan API
    - use Vulkan 1.0 since later versions of Vulkan don't add many features that would be useful to me
- Make sure all of the tests work the same with both Vulkan and OpenGL
    - Make some more tests to really probe for any signifivant behavior differences between the OpenGL and Vulkan implementations
        - Try to include shaders of various types to make sure the SPIR-V binaries work the same


Other things that should be done:
- make sure everything is consistent (Zig style guidelines, except variables and such use camelCase because pascal_case is super annoying to type in my opinion.)
    - If people complain, switch everything to use the actual zig style guidelines instead of my modified version
- use "grep -rnI TODO" to find todos and complete them
- rewrite this readme before the library goes public