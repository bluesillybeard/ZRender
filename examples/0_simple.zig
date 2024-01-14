// This is so that the MockInstance prints everything without skipping data
// TODO: fix this madness (make it an optional argument at callsites rather than a global) and submit a poll request to ziglang
pub const std_options = struct {
    pub const fmt_max_depth = 15;
};

const std = @import("std");
const zrender = @import("zrender");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();
    // Create the instance. It's technically possibly to make multiple of them, but that's a bad idea.
    const instance = try zrender.Instance.initInstance(.{.allocator = allocator});
    defer instance.deinitInstance();
    // Create window.
    const window = try instance.createWindow(.{});
    defer instance.deinitWindow(window);
    // Create the mesh data. This function simply creates the mesh data in a more ergonomic way
    // rather than having to manually convert the vertices into the raw bytes.
    const meshData = zrender.createMeshData(zrender.shader.SolidColor, &[_]zrender.shader.SolidColor.Vertex{
        .{.x = -1, .y = -1},
        .{.x = 1, .y = -1},
        .{.x = 0, .y = 1},
    }, &[_]u32{1, 2, 3});
    // Turn that mesh data into a mesh oject
    const mesh = try instance.createMeshObject(meshData);
    defer instance.deinitMeshObject(mesh);
    // take that mesh object and turn it into a draw object.
    // The only difference between a mesh and a draw object is the draw object is bound to a type of mesh.
    // This allows for using a single mesh for multiple shaders, but still allows for the instance to optimize a mesh for use with a specific shader.
    const drawObject = try instance.createDrawObject(mesh, zrender.shader.ShaderType.SolidColor);
    defer instance.deinitDrawObject(drawObject);
    // TODO: exit event instead of whatever this is
    var count: usize = 0;
    while(count < 100) : (count+=1) {
        // beginFrame tells the instance that draw objects are going to be submitted to windows.
        // Submitting draw objects before calling beginFrame is undefined.
        instance.beginFrame(.{});
        // Submitting objects is done in lists,
        // where each list is a set of objects that can be drawn in any order.
        // Draw lists submitted later will be drawn later.
        instance.submitDrawList(window,
            &[1]zrender.DrawObject{.{
                .object = drawObject,
                .shader = .{.SolidColor = .{
                    .color = .{.r = 1, .g = 0, .b = 1, .a = 1},
                    .transform = zrender.Transform2D.Identity
                }}
            }},
        );
        // finish frame finishes the frame and allows the next frame to begin.
        // This will also wait for vsync.
        instance.finishFrame(.{});
    }
}