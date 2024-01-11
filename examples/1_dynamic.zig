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

    var rng = std.rand.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
    var rand = rng.random();

    const instance = try zrender.Instance.initInstance(.{.allocator = allocator});
    defer instance.deinitInstance();
    const window = try instance.createWindow(.{
        .width = 512,
        .height = 256,
    });
    defer instance.deinitWindow(window);
    // Draw object one is only modified and it sticks to the left side of the window
    const drawData1 = zrender.DrawData {
        .vertexData = zrender.verticesToData(zrender.shader.VertexColor, &[_]zrender.shader.VertexColor.Vertex{
            .{.x = -1, .y = -1, .color = .{.r = 1, .g = 1, .b = 1, .a = 1}},
            .{.x = 0, .y = -1, .color = .{.r = 1, .g = 1, .b = 1, .a = 1}},
            .{.x = -0.5, .y = 0, .color = .{.r = 1, .g = 1, .b = 1, .a = 1}},
        }),
        .indices = &[_]u32{1, 2, 3},
        .shader = zrender.shader.ShaderType.VertexColor,
        // This tells ZRender that this draw object will be modified very frequently
        .usage = .draw_stream,
    };
    const drawObject1 = try instance.createDrawObject(drawData1);
    defer instance.deinitDrawObject(drawObject1);
    // draw object two is replaced every second, and it sticks to the right side
    const drawData2 = zrender.DrawData {
        .vertexData = zrender.verticesToData(zrender.shader.VertexColor, &[_]zrender.shader.VertexColor.Vertex{
            .{.x = 0, .y = 0, .color = .{.r = 1, .g = 1, .b = 1, .a = 1}},
            .{.x = 1, .y = 0, .color = .{.r = 1, .g = 1, .b = 1, .a = 1}},
            .{.x = 0.5, .y = 1, .color = .{.r = 1, .g = 1, .b = 1, .a = 1}},
        }),
        .indices = &[_]u32{1, 2, 3},
        .shader = zrender.shader.ShaderType.VertexColor,
        // This one is only modified every second, so it's not streaming but still writable.
        .usage = .draw_write,
    };
    const drawObject2 = try instance.createDrawObject(drawData2);
    defer instance.deinitDrawObject(drawObject2);
    var lastDrawObject2ReplacementMillis = std.time.milliTimestamp();
    // TODO: exit event instead of whatever this is
    var count: usize = 0;
    while(count < 100) : (count+=1) {
        instance.beginFrame(.{});
        instance.submitDrawList(window,
            &[2]zrender.DrawObject{
                .{
                    .object = drawObject1,
                    .shader = .{.VertexColor = .{
                        .transform = zrender.Transform2D.Identity
                    }}
                },
                .{
                    .object = drawObject2,
                    .shader = .{.VertexColor = .{
                        .transform = zrender.Transform2D.Identity
                    }}
                }
            },
        );
        instance.finishFrame(.{});
        // Randomize the vertex locations of draw object one
        const drawDiff1 = zrender.DrawDiff{
            .indexStart = 0,
            .indexData = &[0]u32{},
            .vertexStart = 0,
            .vertexData = zrender.verticesToData(zrender.shader.VertexColor, &[_]zrender.shader.VertexColor.Vertex{
                .{.x = rand.float(f32) - 1, .y = rand.float(f32) - 1, .color = .{.r = rand.float(f32), .g = rand.float(f32), .b = rand.float(f32), .a = 1}},
                .{.x = rand.float(f32) - 1, .y = rand.float(f32) - 1, .color = .{.r = rand.float(f32), .g = rand.float(f32), .b = rand.float(f32), .a = 1}},
                .{.x = rand.float(f32) - 1, .y = rand.float(f32) - 1, .color = .{.r = rand.float(f32), .g = rand.float(f32), .b = rand.float(f32), .a = 1}},
            })
        };
        instance.modifyDrawObject(drawObject1, drawDiff1);
        // If it's been one second
        const nowMillis = std.time.milliTimestamp();
        if(nowMillis - lastDrawObject2ReplacementMillis > 1000) {
            lastDrawObject2ReplacementMillis = nowMillis;
            // create a new completely random draw data
            var verticesBuffer = [_]zrender.shader.VertexColor.Vertex{.{.x = 0, .y = 0, .color = .{.r = 1, .g = 1, .b = 1, .a = 1}}} ** (100 * 3);
            var indicesBuffer = [_]u32{0} ** (100 * 3);
            const numVertices = rand.intRangeAtMost(usize, 1, 100) * 3;
            for(0 .. numVertices) |i| {
                verticesBuffer[i] = .{.x = rand.float(f32), .y = rand.float(f32), .color = .{.r = rand.float(f32), .g = rand.float(f32), .b = rand.float(f32), .a = 1}};
                indicesBuffer[i] = @intCast(i);
            }
            // and replace draw object 2 with the new one
            instance.replaceDrawObject(drawObject2, .{
                .indices = indicesBuffer[0..numVertices],
                .vertexData = zrender.verticesToData(zrender.shader.VertexColor, verticesBuffer[0..numVertices]),
                .shader = .VertexColor,
                .usage = .draw_write,
            });
        }
    }
}