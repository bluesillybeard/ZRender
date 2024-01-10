# TODO

## Right now

- mock backend
- implement examples that use all of the features

## very very soon

- ability to set the clear color and to disable clearing before drawing
    - clear options are given as a struct for the OnFrame method


## Before starting work on Celestial:

Features:
- textures
- dynamically modifying loaded assets
- all the events
- window stuff
    - getting / setting window position
    - getting / setting window size
    - 

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
