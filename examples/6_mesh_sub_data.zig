// This does the same as example 5_mesh_replace_data, but the number of triangles stays the same.

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
    numVertices: usize,
    numIndices: usize,
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
            // Create a temporary buffer to upload an empty mesh
            var buffer = data.allocator.alloc(u32, data.numIndices + data.numVertices) catch unreachable;
            defer data.allocator.free(buffer);
            for(0 .. buffer.len) |i| {
                buffer[i] = 0;
            }
            const vertexBuffer = buffer[0 .. data.numIndices];
            const indexBuffer = buffer[data.numIndices ..];
            for(0 .. indexBuffer.len) |i| {
                indexBuffer[i] = @intCast(i % @divTrunc(vertexBuffer.len, 5));
            }
            data.mesh = instance.loadMesh(queue, .triangles, .render,
                &[_]ZRender.MeshAttribute{.vec2, .vec3},
                u32SliceToBytes(vertexBuffer), indexBuffer).?;
        }
        // Every second, randomly change 3 vertices and 3 indices.
        if(data.lastChange + std.time.us_per_s < time) {
            // Randomize some vertices
            for(0 .. 10) |i|{
                _ = i;
                // get an random index into the vertices
                const randomIndex = data.rng.intRangeLessThan(usize, 0, data.numVertices);
                // create a random number to write to that index
                var value = data.rng.float(f32);
                // Figure out if it's a color or a position
                const attribute = randomIndex % 5;
                // If it's a position, multiply it by 2 and subtract 1 so it covers the entire screen
                if(attribute < 2) value = value * 2 - 1;

                // update the mesh with that modification.
                // Usually you'll want to change more than one vertex at a time.
                instance.substituteMeshVertexBuffer(queue, data.mesh.?, randomIndex * @sizeOf(f32), floatSliceToBytes(&[1]f32{value}));
            }
            // Randomize some indices (I will refer to them as elements)
            for(0 .. 50) |i|{
                _ = i;
                // get an random index into the elements
                const randomIndex = data.rng.intRangeLessThan(usize, 0, data.numIndices);
                // create a random element to write to that index
                // The range is divided by 5 since the element refers to an entire vertex, not a single float.
                const value = data.rng.intRangeLessThan(u32, 0, @intCast(@divTrunc(data.numVertices, 5)));
                // update the mesh with that modification.
                // Usually you'll want to change more than one element at a time.
                instance.substituteMeshIndices(queue, data.mesh.?, randomIndex, &[1]u32{value});
            }
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
        .numVertices = 50,
        // More indices to guarantee vertices are shared.
        .numIndices = 99,
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
fn u32SliceToBytes(i: []const u32)[]const u8 {
    var r: []const u8 = undefined;
    r.ptr = @ptrCast(i.ptr);
    r.len = i.len * 4;
    return r;
}

fn floatSliceToBytes(i: []const f32)[]const u8 {
    var r: []const u8 = undefined;
    r.ptr = @ptrCast(i.ptr);
    r.len = i.len * 4;
    return r;
}