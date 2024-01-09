# TODO

## Current API reform

- It might be worth just making the mesh and shader tied together completely - a mesh is bound to a shader, and that's that
- make a draw object the union(enum), and make the mesh(es) fields of shaders instead of a drawObject containing a mesh and a shader
- replacing or modifying mesh data
- [RIO] remove implicit ordering and add a way to explicitly declare draw order
    - This should make optimizations like draw batching and instanced rendering easier and more effective

- ability to set the clear color and to disable clearing before drawing
    - clear options are given as a struct for the OnFrame method


## Before starting work on Celestial:

Features:
- textures
- dynamically modifying loaded assets
- all the events

## Before the first alpha 'releases':

Features:
- more shaders
    - textured with vertex color
    - textured with luminance
    - blending and non-blending version of shaders
        - maybe better with some settings as part of DrawObject instead of separate shaders
    - 3D shaders
    - depth testing
        - Maybe better as a flag rather than separate shaders
    - more optimized versions for lower memory usage
        - alternates where color is 4 bytes instead of 4 floats
        - alternates where color only has RGB, not the alpha channel
- custom animated vector graphics format
    - Might be worth making the animation data and the actual graphics separate. Animation data would depend on graphics data, but the graphics data would hold its own.
- render textures - render to a texture instead of just the window
    - works like a virtual window that takes draw objects like a normal window, but it can be used as a texture as well
- shaders that could actually make use of render texturs
    - post-processing shaders
    - Might be an easy first step before custom shaders, since the inputs and outputs can be pre-defined

Bugfixes or QOL:
- Create standalone documentation
- Improve formatting of the Mock backend output
- In the OpenGL 4.6 backend, deleting GPU objects after the last window is deleted causes OpenGL functions to be called without a context.
    - found using apitrace

Optimizations:
- In the OpenGL 4.6 backend, merge draw calls together
    - Don't do this until [RIO] is done
