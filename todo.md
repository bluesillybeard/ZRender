# TODO

This is a list of TODO items that are reasonably high priority.
Essentially, a set of next steps.

Right now, these steps are quite fundamental as the library is quite new, however 

Larger feature additions should be put in [`readme.md`](./readme.md)

Features:
- replacing or modifying mesh data
- textures
- more shaders
    - vertex colors
    - textured shaders
    - multiple shaders
    - blending and non-blending version of shaders
        - maybe better with some settings as part of DrawObject instead of separate shaders
    - 3D shaders
    - depth testing
        - Maybe better as a flag rather than separate shaders
- remove implicit ordering and add a way to explicitly declare draw order
    - This should make optimizations like draw batching and instanced rendering easier and more effective
- ability to set the clear color and to disable clearing before drawing
- dynamically modifying loaded assets


Bugfixes or QOL:
- Create standalone documentation
- Improve formatting of the Mock backend output

Optimizations:
- In the OpenGL 4.6 backend, merge draw calls together
    - Because drawing is ordered, 
