const ZRender = @import("zrender").ZRender(.{
    .CustomWindowData = MeshWindow,
    .CustomInstanceData = Data,
});
const std = @import("std");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub const Data = struct {
    mesh: ?*ZRender.Mesh = null,
    ml: bool,
};

pub const MeshWindow = struct {
    pub fn onRender(instance: ZRender.Instance, window: *ZRender.Window, queue: *ZRender.RenderQueue, delta: i64, time: i64) void {
        _ = window;
        _ = delta;
        _ = time;
    
        var data: *Data = instance.getCustomData();
        if(data.mesh == null) {
            data.mesh = instance.loadMesh(queue, ZRender.MeshType.quads, ZRender.MeshUsageHint.render,
                &[_]ZRender.MeshAttribute{.vec2},
                &[_]u8{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 0, 0
                       0x00, 0x00, 0x80, 0x3f, 0x00, 0x00, 0x00, 0x00, // 1, 0
                       0x00, 0x00, 0x80, 0x3f, 0x00, 0x00, 0x80, 0x3f, // 1, 1
                       0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f, // 0, 1
                       },
                &[_]u32{1, 2, 3, 4}
            );
        }

        if(instance.isMeshLoaded(data.mesh.?)){
            std.debug.print("Mesh was loaded successfully", .{});
            data.ml = true;
        }

        instance.clearToColor(queue, ZRender.Color{.r = 0, .g = 0, .b = 0, .a = 1});
        instance.presentFramebuffer(queue, true);
    }
    pub fn onDeinit(instance: ZRender.Instance, window: *ZRender.Window, time: i64) void {
        _ = instance;
        _ = window;
        _ = time;
    

    }
    pub fn onEvent(instance: ZRender.Instance, window: *ZRender.Window, event: ZRender.ZRenderWindowEvent, time: i64) void {
        _ = instance;
        _ = window;
        _ = event;
        _ = time;
    

    }
};
pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();
    var d = Data{
        .mesh = null,
        .ml = false,
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