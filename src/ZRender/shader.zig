const bits = @import("bits.zig");

/// enumeration of shader types
pub const ShaderType = enum {
    SolidColor,
    VertexColor,
};

/// uniform information for SolidColor shader
pub const SolidColor = struct {
    color: bits.Color,
    transform: bits.Transform2D,
};

/// vertex type for SolidColor shader
pub const SolidColorVertex = extern struct{
    x: f32, y: f32,
};

/// uniform information for VertexColor shader
pub const VertexColor = struct {
    transform: bits.Transform2D,
};

/// vertex information for VertexColor shader
pub const VertexColorVertex = extern struct {
    x: f32, y: f32, color: bits.Color,
};

/// main shader type
pub const Shader = union(ShaderType) {
    SolidColor: SolidColor,
    VertexColor: VertexColor,
};