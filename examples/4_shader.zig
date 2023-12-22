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
    l: bool = false,
    exiting: bool = false,
};

pub const MeshWindow = struct {
    pub fn onRender(instance: ZRender.Instance, window: *ZRender.Window, queue: *ZRender.RenderQueue, delta: i64, time: i64) void {
        _ = delta;
        _ = time;
    
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

        if(instance.isShaderLoaded(data.shader.?) and !data.l){
            std.debug.print("Shader was loaded successfully\n", .{});
            data.l = true;
        }
        instance.clearToColor(queue, ZRender.Color{.r = 0, .g = 0, .b = 0, .a = 255});
        instance.draw(queue, data.shader.?, &[_]ZRender.DrawInstance{.{
            .numElements=3,
            .mesh = data.mesh.?,
        }});
        instance.presentFramebuffer(queue, true);

        if(data.exiting) {
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
    var d = Data{
        .shader = null,
        .l = false,
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