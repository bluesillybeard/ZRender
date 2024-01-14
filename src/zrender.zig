// this is the file to import.
// It contains forward declarations of everything an application might need
const instance = @import("instance.zig");

pub const shader = @import("shader.zig");

pub const InstanceOptions = instance.InstanceOptions;
pub const Instance = instance.Instance;

/// A color, extern so less conversion overhead is required by the underlying API
pub const Color = extern struct {
    r: f32, g: f32, b: f32, a: f32,
};

/// A 3x3 matrix, extern so less conversion overhead is required by the underlying API
pub const Matrix3 = extern struct {
    // X      Y         Z
    m00: f32, m01: f32, m02: f32, //X
    m10: f32, m11: f32, m12: f32, //Y
    m20: f32, m21: f32, m22: f32, //Z

    pub const Identity = Matrix3 {
        .m00 = 1, .m01 = 0, .m02 = 0,
        .m10 = 0, .m11 = 1, .m12 = 0,
        .m20 = 0, .m21 = 0, .m22 = 1,
    };
    // TODO: mathmatical functions and stuff
};

pub const Transform2D = struct {
    matrix: Matrix3,

    // TODO: transformation functions

    /// Identity transformation - no change from input
    pub const Identity = Transform2D{
        .matrix = Matrix3.Identity,
    };
};

// Window related types
pub const WindowSettings = struct {
    width: u32 = 800,
    height: u32 = 600,
    name: [:0]const u8 = "ZRender window",
    yPos: ?u32 = null,
    xPos: ?u32 = null,
    resizable: bool = false,
};

/// A handle to a window
pub const WindowHandle = usize;

/// a handle to a mesh
pub const MeshObjectHandle = usize;

/// Raw mesh data
pub const MeshData = struct {
    vertexData: []const u8,
    indices: []const u32,
};

pub fn createMeshData(comptime Shader: type, vertices: []const Shader.Vertex, indices: []const u32) MeshData {
    return MeshData{
        .vertexData = verticesToData(Shader, vertices),
        .indices = indices,
    };
}

/// A handle to a draw object
pub const DrawObjectHandle = usize;

/// usage hint for a draw object
pub const DrawObjectUsage = enum {
    /// object is used for drawing
    draw,
    /// object is used for drawing and is sometimes modified
    draw_write,
    /// object is used for drawing and is modified every frame or so
    draw_stream,
};

pub fn verticesToData(comptime Shader: type, vertices: []const Shader.Vertex) []const u8 {
    var data: []const u8 = undefined;
    data.len = vertices.len * @sizeOf(Shader.Vertex);
    data.ptr = @ptrCast(vertices.ptr);
    return data;
}

/// Draw object ready for drawing.
/// If the type of the shader data is not the same as the shader type of the draw object, that is undefined behavior.
pub const DrawObject = struct {
    object: DrawObjectHandle,
    shader: shader.Shader,
};

/// a modification to draw data
pub const DrawDiff = struct {
    /// start byte for modifying vertex data
    vertexStart: usize,
    /// vertex data to write at the offset.
    /// If the number of vertices would increase from the modification, that is undefined behvior
    vertexData: []const u8,
    /// the start index for modifying indices
    indexStart: usize,
    /// the indices to modify.
    /// If the number of indices would increase from the modification, that is undefined behvior
    indexData: []const u32,
};


pub const Event = union(enum) {

};

pub const BeginFrameArgs = struct {

};

pub const FinishFrameArgs = struct {
    vsync: bool = true,
};