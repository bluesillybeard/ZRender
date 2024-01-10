const zrender = @import("zrender.zig");

/// enumeration of shader types
pub const ShaderType = enum {
    SolidColor,
    VertexColor,
};

/// uniform information for SolidColor shader
pub const SolidColor = struct {
    color: zrender.Color,
    transform: zrender.Transform2D,
    pub const Vertex = extern struct {
        x: f32, y: f32,
    };
};


/// uniform information for VertexColor shader
pub const VertexColor = struct {
    transform: zrender.Transform2D,
    pub const Vertex = extern struct {
        x: f32, y: f32, color: zrender.Color,
    };
};

/// main shader type for shader uniform data.
pub const Shader = union(ShaderType) {
    SolidColor: SolidColor,
    VertexColor: VertexColor,
};