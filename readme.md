# ZRender - Official rendering module for ZEngine

Currently, it is extremely simple - a draw component is simply these things:
- Handle to a 3D mesh
- Handle to a 2D texture
- A 4x4 transform matrix

... And that's it. reprogrammable shaders are not a feature at the moment, and likely won't be for a while unless someone wants to add that feature in a PR.

## Accepted mesh formats
- None. Right now, a mesh is created by calling a function with the raw mesh data. Loading meshes from a file will be supported later

## Accepted texture formats
- PNG

## Matrix transforms
Right now, you're on your own in terms of creating the transform matrix. In the future, there will be a myriad of utilities for creating matrix transforms in an ergonomic way.
