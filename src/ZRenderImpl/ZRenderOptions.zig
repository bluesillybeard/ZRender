//! ZRender compile time settings (these are like C macros)

/// Custom data that is part of the instance. use instance.getCustomData() to retrieve it.
CustomInstanceData: type = void,
/// Custom data that is part of each window. use instance.getCustomWindowData(window) to retrieve it.
CustomWindowData: type = void,