// Example for drawing with a basic shader.

const ZRender = @import("zrender").ZRender(.{
    .CustomWindowData = MeshWindow,
    .CustomInstanceData = Data,
});
const std = @import("std");
const alloc = std.heap.GeneralPurposeAllocator(.{});
const shader_embeds = @import("shader_embeds");


pub const Data = struct {
    shader: ?*ZRender.Shader = null,
    mesh: ?*ZRender.Mesh = null,
    exiting: bool = false,
    lastChange: i64 = 0,
    rng: std.rand.Random,
    allocator: std.mem.Allocator,
};

pub const MeshWindow = struct {
    pub fn onRender(instance: ZRender.Instance, window: *ZRender.Window, queue: *ZRender.RenderQueue, delta: i64, time: i64) void {
        _ = delta;
    
        var data: *Data = instance.getCustomData();
        if(data.shader == null) {
            data.shader = instance.loadShaderProgram(queue,
                &[_]ZRender.MeshAttribute{.vec2, .vec3}, //The vec2 is the position input, the vec3 is the color.
                // This is the compiled output from the glsl shaders.
                // Look at shaders/4_shader.*, shaders/readme.md for more info.
                shader_embeds.@"4_shader.vert.spv",
                shader_embeds.@"4_shader.frag.spv",
            ).?;

            data.mesh = instance.loadMesh(queue, .triangles, .render,
            &[_]ZRender.MeshAttribute{.vec2, .vec3},
            // ZRender takes in vertices as if they were put into an extern struct with fields matching the attributes,
            // So casting a float array like this is perfectly valid.
            floatSliceToBytes(&[_]f32{
                 //X    Y    R    G    B
                 0.0,-0.5, 1.0, 0.0, 0.0,
                 0.5, 0.5, 0.0, 1.0, 0.0,
                -0.5, 0.5, 0.0, 0.0, 1.0,
            }), &[_]u32{0, 1, 2}).?;
        }
        // Every second
        if(data.lastChange + std.time.us_per_s < time) {
            // generate a random mesh
            // somewhere between 0 and 255 triangles
            const numTriangles: usize = data.rng.int(u8);
            std.debug.print("Drawing {} triangles\n", .{numTriangles});
            var vertices = std.ArrayList(f32).initCapacity(data.allocator, numTriangles * 3 * 5) catch unreachable;
            defer vertices.deinit();
            var indices = std.ArrayList(u32).initCapacity(data.allocator, numTriangles * 3) catch unreachable;
            defer indices.deinit();
            for(0 .. numTriangles) |triangle| {
                _ = triangle;
                for(0 .. 3) |vertex| {
                    _ = vertex;
                    for(0 .. 5) |index| {
                        _ = index;
                        vertices.append(data.rng.float(f32) * 2 - 1) catch unreachable;
                    }
                    indices.append(@intCast(indices.items.len)) catch unreachable;
                }
            }
            instance.setMeshData(queue, data.mesh.?, floatSliceToBytes(vertices.items), indices.items);
            data.lastChange = time;
        }


        instance.clearToColor(queue, ZRender.Color{.r = 0, .g = 0, .b = 0, .a = 255});
        instance.draw(queue, data.shader.?, &[_]ZRender.DrawInstance{.{
            .mesh = data.mesh.?,
        }});
        instance.presentFramebuffer(queue, true);

        if(data.exiting) {
            instance.unloadMesh(queue, data.mesh.?);
            instance.unloadShader(queue, data.shader.?);
            instance.deinitWindow(window);
        }
    }
    pub fn onDeinit(instance: ZRender.Instance, window: *ZRender.Window, time: i64) void {
        _ = instance;
        _ = window;
        _ = time;
    

    }
    pub fn onEvent(instance: ZRender.Instance, window: *ZRender.Window, event: ZRender.ZRenderWindowEvent, time: i64) void {
        _ = window;
        _ = time;

        var data: *Data = instance.getCustomData();

        switch (event) {
            .exit => {
                data.exiting = true;
            }
        }
    

    }
};
pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();
    var random = std.rand.DefaultPrng{
        .s = undefined,
    };
    random.seed(@bitCast(std.time.microTimestamp()));
    var d = Data{
        .rng = random.random(),
        .allocator = allocator,
    };
    // create an instance with default parameters
    var instance = try ZRender.init(allocator, &d);
    defer instance.deinit();
    var m = MeshWindow{};
    // Create our setup
    const setup = ZRender.ZRenderSetup{
        .customData = &m,
        .onRender = MeshWindow.onRender,
        .onDeinit = MeshWindow.onDeinit,
        .onEvent = MeshWindow.onEvent,
    };
    _ = instance.initWindow(.{}, setup.makeFake()).?;
    // This runs the instance. It also implicitly ends the lifetimes of all the windows, so be careful with that.
    instance.run();
}

// TODO: remove when @ptrCast works when the slice would change length
fn floatSliceToBytes(i: []const f32)[]const u8 {
    var r: []const u8 = undefined;
    r.ptr = @ptrCast(i.ptr);
    r.len = i.len * 4;
    return r;
}