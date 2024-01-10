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

    const instance = try zrender.Instance.initInstance(.{.allocator = allocator});
    defer instance.deinitInstance();
    const window = try instance.createWindow(.{});
    defer instance.deinitWindow(window);
    const drawData = zrender.DrawData {
        .vertexData = zrender.verticesToData(zrender.shader.SolidColor, &[_]zrender.shader.SolidColor.Vertex{
            .{.x = -1, .y = -1},
            .{.x = 1, .y = -1},
            .{.x = 0.5, .y = 1},
        }),
        .indices = &[_]u32{1, 2, 3},
        .shader = zrender.shader.ShaderType.SolidColor,
    };
    const drawObject = try instance.createDrawObject(drawData);
    defer instance.deinitDrawObject(drawObject);
    // TODO: exit event instead of whatever this is
    var count: usize = 0;
    while(count < 100) : (count+=1) {
        instance.beginFrame(.{});
        instance.submitDrawList(window,
            &[1]zrender.DrawObject{.{
                .object = drawObject,
                .shader = .{.SolidColor = .{
                    .color = .{.r = 1, .g = 0, .b = 1, .a = 1},
                    .transform = zrender.Transform2D.Identity
                }}
            }},
        );
        instance.finishFrame(.{});
    }
}