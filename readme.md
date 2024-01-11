# ZRender

## yet again I rewrite the project
Here's the kind of rendering I need for Celestial, at a high level:
- fast animated SVG
    - gradients
    - images
    - Ultimately, the pipeline will probably look like this rather than trying to draw the SVGs directly:
        - SVG -> custom animation software -> custom file format -> the game

- decent cross-platform support
    - a high level API that can theoretically be implemented for any platform
- multiple windows
    - All secondary windows will contain UI, although being able to render anything would be nice
- 2D
- development time is not a big concern; there is no deadline

ZRender is a simple cross platform windowing + rendering system written in Zig.

It is designed for one of my personal projects (A video game vaguely inspired by Starbound), but I guess anyone can use it if they want to.

## The program lifecycle looks like this
- init stuff
- each frame:
    - instance.beginFrame
    - submit objects to draw
    - instance.renderFrame
    - do whatever CPU stuff
        - this inclues loading asses and creating/destroying windows
- delete stuff

The only real requirement for init stuff is to create an instance,
Although it's not a bad idea to create a window and load some of the assets during that time too.

instance.beginFrame tells the instance that you are about to start loading it with objects to draw.
Trying to load objects before calling beginFrame is undefined behavior.

Doing other things (such as loading assets or creating/destroying windows) during this time is considered undefined behavior. Do that after renderFrame is called.

Objects are submitted in lists. Objects within a list have no defined draw order, but lists submitted separately are guaranteed to be drawn separately in the same order they are submitted.

instance.finishFrame blocks for vsync in the same way that GLFW or SDL2 block when calling swapBuffers. Which is to say, it might *not* block in order to load the GPU with more stuff to do.

The order in which objects are deleted does not matter, as long as the instance is deleted last.

## Note about development
- Because I created this library for my own use, don't expect much. I will gladly accept poll requests though!
- This library is still new, so expect breaking changes frequently
<!--
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
