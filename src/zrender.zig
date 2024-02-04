const std = @import("std");
const registry = @import("registry.zig");
const zengine = @import("zengine.zig");
const ecs = @import("ecs");

pub const RenderComponent = struct {
    mesh: Mesh,
    texture: Texture,
    transform: Mat4
};

pub const Vertex = extern struct {
    x: f32, y: f32, z: f32,
    texY: f32, texX: f32,
    /// Red is the least significant byte, Alpha is the most significant
    color: u32,
    /// 0 -> texture, 1 -> color
    blend: f32,
};

// A handle to a mesh object
pub const Mesh = usize;

pub const Texture = usize;

pub const Mat4 = extern struct {
    m00: f32, m01: f32, m02: f32, m03: f32,
    m10: f32, m11: f32, m12: f32, m13: f32,
    m20: f32, m21: f32, m22: f32, m23: f32,
    m30: f32, m31: f32, m32: f32, m33: f32,

    pub const identity = Mat4{
        .m00 = 1, .m01 = 0, .m02 = 0, .m03 = 0,
        .m10 = 0, .m11 = 1, .m12 = 0, .m13 = 0,
        .m20 = 0, .m21 = 0, .m22 = 1, .m23 = 0,
        .m30 = 0, .m31 = 0, .m32 = 0, .m33 = 1,
    };
};

/// ZEngine rendering system
pub const ZRenderSystem = struct {
    pub const name: []const u8 = "zrender";
    pub const components = [_]type{RenderComponent};
    pub fn comptimeVerification(comptime options: zengine.ZEngineComptimeOptions) bool {
        // TODO
        _ = options;
        return true;
    }

    pub fn init(staticAllocator: std.mem.Allocator, heapAllocator: std.mem.Allocator) @This() {
        _ = heapAllocator;
        _ = staticAllocator;
        return .{};
    }

    pub fn systemInitGlobal(this: *@This(), registries: zengine.RegistrySet) !void {
        _ = registries;
        _ = this;
    }

    pub fn systemDeinitGlobal(this: *@This(), registries: zengine.RegistrySet) void {
        _ = registries;
        _ = this;
    }

    pub fn deinit(this: *@This()) void {
        _ = this;

    }
};

