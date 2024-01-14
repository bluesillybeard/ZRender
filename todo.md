# TODO

## Major refactor idea:

Currently it works like this:
- mesh data + shader type -> mesh object handle (which is tied to a shader)
- mesh object handle + shader data -> draw object
- draw object -> render

It would be better like this:
- mesh data -> mesh object handle
- mesh object + shader -> draw object handle
- draw object handle + shader data -> render

Basically, separate the draw object from the mesh data

## Right now (well, relatively speaking)

- all the events
    - clipboard
    - 
- implement examples that use all of the features
- ability to set the clear color and to disable clearing before drawing
    - clear options are given as a struct for the OnFrame method


## Before moving Celestial to ZRender instead of Raylib:

Features:
- textures
- dynamically modifying loaded assets
- window stuff
    - getting / setting window position
    - getting / setting window size
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
    - vertex animation textures
    - shaders for rigged animations
        - I would have to do more research into how exactly that works


## Before the first alpha 'releases':

- render textures - render to a texture instead of just the window
    - works like a virtual window that takes draw objects like a normal window, but it can be used as a texture as well
- more shaders
    - more optimized versions for lower memory usage
        - alternates where color is 4 bytes instead of 4 floats
        - alternates where color only has RGB, not the alpha channel
- shaders that could actually make use of render texturs
    - post-processing shaders
    - Might be an easy first step for custom shaders, since the inputs and outputs can be pre-defined
- Create standalone documentation
- Improve formatting of the Mock backend output
