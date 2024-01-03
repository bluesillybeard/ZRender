const interface = @import("interface");

// A bunch of small types

// Window related types
pub const WindowSettings = struct {
    width: u32 = 800,
    height: u32 = 600,
    name: [:0]const u8 = "ZRender window",
    yPos: ?u32 = null,
    xPos: ?u32 = null,
    resizable: bool = false,
};

pub const WindowHandle = usize;

// TODO: more specific errors
pub const CreateWindowError = error {
    createWindowError
};

// shader type
pub const Shader = union(enum) {
    /// Draws a mesh with a single solid color.
    /// Mesh Attributes: position (x: f32, y: f32)
    /// Other data: rgba color, floats where 0 -> black and 1 -> white
    SolidColor: struct{r: f32, g: f32, b: f32, a: f32},
};

// A handle to an actual mesh on the GPU
pub const MeshHandle = usize;

/// Instance contains that majority of the public API (well the part of the API that interacts with actual stuff)
pub fn MakeInstance(comptime This: type) type {
    return struct {
        pub fn createWindow(this: This, s: WindowSettings) CreateWindowError!WindowHandle {
            this.vtable.createWindow(this.object, s);
        }
    };
}

pub const Instance = interface.MakeInterface(MakeInstance, .{});