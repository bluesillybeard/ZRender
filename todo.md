# TODO

## Before starting work on Celestial:

Features:
- replacing or modifying mesh data
- textures
- [RIO] remove implicit ordering and add a way to explicitly declare draw order
    - This should make optimizations like draw batching and instanced rendering easier and more effective
- dynamically modifying loaded assets

## Before the first alpha 'releases':

Features:
- more shaders
    - textured shaders
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
- ability to set the clear color and to disable clearing before drawing

Bugfixes or QOL:
- Create standalone documentation
- Improve formatting of the Mock backend output
- In the OpenGL 4.6 backend, deleting GPU objects after the last window is deleted causes OpenGL functions to be called without a context.
    - found using apitrace

Optimizations:
- In the OpenGL 4.6 backend, merge draw calls together
    - Don't do this until [RIO] is done
