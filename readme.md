# ZRender

## yet again I rewrite the project
Here's the kind of rendering I need for Celestial, at a high level:
- fast animated SVG
    - probably with a custom format to keep things simpler and easier
        - Since the SVG will be translated into a mesh for fast rendering
    - gradients
    - images
- decent cross-platform support
    - a high level API that can theoretically be implemented for any platform
- multiple windows
    - All secondary windows will contain UI, although being able to render anything would be nice
- 2D
- development time is not a big concern; there is no deadline

ZRender is a simple cross platform windowing + rendering system written in Zig.

It is designed for one of my personal projects (A video game vaguely inspired by Starbound), but I guess anyone can use it if they want to.

## The main loop looks like something this
- create an instance
- create at least one window because OpenGL is freaking stupid and requires a window before anything can happen
- Every frame:
    - enumerate events
    - create or destroy windows
    - create draw objects from draw data
        - draw data can be loaded from files or created directly
        - Reuse draw objects between frames, in fact it's often best to load everything before the main loop technically begins
        - you can also modify existing draw objects to reduce overhead
        - Note that ZRender generally takes a lazy approach - the draw data will not be finalized until it looks like it's about to be used, so if you want to load assets ahead of time, use `fakeUseDrawObject` to guarantee that it will be finalized during this frame.
    - Submit draw object(s) to window(s)
        - Objects are submited in lists, where each list is an unordered set of objects.
        - Draw lists have an order though - draw lists are processed in the same order they are submitted, in case your rendering is order dependent.
    - BeginDrawing instance function
        - takes a set of windows to begin processing
        - the instance will be basically unusable until the frame is done drawing
    - Do whatver CPU things that should be done (game logic, loading files, really anything that doesn't require the interface)
    - FinishDrawing instance function
        - Will finish drawing for the same set of windows given to BeginDrawing
        - Resets the draw lists for those windows
    - DisplayFrame instance function

## Note about development
- Because I created this library for my own use, don't expect much. I will gladly accept poll requests though!
- This library is still new, so expect breaking changes frequently

<!-- ignore this garbage -->
<!-- ZRender is a simple cross platform rendering + windowing system written in Zig.

What is the purpose of ZRender?
- To be a simple but powerful rendering system, mainly for my own projects.

What are the design goals of ZRender?
1. Take advantage of Zig's strengths
    - interfacing with C
    - compile time metaprogramming
    - cross-compilation
    - custom allocators
2. Focus on rendering
    - No entity management, no physics, no networking, no scripting. Just plain rendering. If you want those things, add them yourself.
3. Minimal API
    - As few distinct functions as possible

## How to use ZRender
- look at examples:
    - [`0_simple.zig`](./examples/0_simple.zig)
    - [`1_triangle.zig`](./examples/1_triangle.zig)
- Look at [`build.zig`](./build.zig) to see how to add ZRender to your own project

Supported platforms:
- Windows (untested at the moment, but it almost certainly works perfectly)
- Linux (in theory any unix-like with SDL2 and at least one of the supported APIS should work)

Backends:
- OpenGL 4.6
- Mock - it just prints out the functions that are called, and returns plausible values. It's used for testing.

Runtime dependencies:
- SDL2 (It also needs to be available at compile time so the executable can be linked against it)
- OpenGL 4.6

Compile time dependencies:
- Zig 0.12.0-dev.1819+5c1428ea9 (doesn't need to be in path, just used to run the build.zig)

Notes about documentation:
- All methods must be called from the main thread, unless explicitly stated otherwise
- Documentation is sparse at the moment, as the library is still fresh and documentation is not yet written

Notes about development:
- Because I created this library for my own use, don't expect much. I will gladly accept poll requests though!
- This library is still new, so expect breaking changes frequently

Platforms I want to support in the near future
- Macos
    - Requries Metal backend
- BSD (This likely already works, I just don't want to bother testing it and actually making sure it works)

Platforms I want to support in the far future:
- Andriod
- IOS
- Playstation 4, 5, maybe PS3???
    - Might require another backend, needs research
- XBox
    - I imagine XBOX supports Vulkan, but if not a DirectX backend probably won't be too dificult
- Nintendo switch (If I'm not mistaken, the Nintendo switch OS is basically just a modified version of Andriod)
- any other modern-ish game consoles
- WebGL (If WebGPU catches on, then webGL will be pointless to support)
    - Compiling Zig code for Emscripten is still a bit of a mess at the moment, hopefully that changes soon.
- WebGPU

Features that might get added in the future:
- ability to retrieve platform-specific handles for users who need to use native APIS
- custom file loading through callbacks (defaults to normal file system)
- support for as many asset formats as possible (as well as custom ones for maximum efficiency)
    - stbImage
    - Assimp
    - Loading SVG as a list of DrawObjects
- Custom shaders
- thread safe / asynchronous alternatives for most existing functions
- submit an entire list to a window instead of individual draw objects
- animation
    - joints / bones / armature / whatever the heck that is even called anymore
    - vertex animation textures

Backends I want to implement in the future:
- OpenGL 3.3 for legacy systems
- OpenGL 2.1 for extremely legacy systems
- Vulkan
- Metal
- OpenGL ES (for webgl)
- If SDL2's renderer is up to the task, a backed that exclusively uses that might be worth doing
- Validation layer
    - Similar concept to Vulkan's validation layers, but instead of being a shared library loaded between the app and the driver, it's just a ZRender backend that verifies valid usage of ZRender, then forwards the functions to another backend.
- Zero dependency software renderer
    - Not sure how the rendered frames would be displayed though.
- WebGPU

 -->
