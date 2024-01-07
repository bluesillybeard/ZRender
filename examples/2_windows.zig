// Example for creating multiple windows in ZRender

const std = @import("std");
const ZRender = @import("zrender");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();
    // Create instance with default options
    var instance = try ZRender.initInstance(.{.allocator = allocator});
    defer instance.deinit();

    // Create a window with default options
    const window1 = try instance.createWindow(.{});
    defer instance.deinitWindow(window1);
    // Create another window
    const window2 = try instance.createWindow(.{});
    defer instance.deinitWindow(window2);
    // Create another window
    const window3 = try instance.createWindow(.{});
    defer instance.deinitWindow(window3);

    // Create draw objects with a single solid color triangle
    const mesh = try instance.createMeshf32(&[_]f32{0.5, -0.5, -0.5, -0.5, 0.5, 0.5}, &[_]u32{0, 1, 2}, .draw);
    defer instance.deinitMesh(mesh);

    // Magenta triangle
    const triangle1 = ZRender.DrawObject{
        .draws = &[1]ZRender.MeshHandle{mesh},
        .shader = .{.SolidColor = .{.color = .{.r = 1, .g = 0, .b = 1, .a = 1}, .transform = ZRender.Transform2D.Identity}},
    };

    // Cyan triangle
    const triangle2 = ZRender.DrawObject{
        .draws = &[1]ZRender.MeshHandle{mesh},
        .shader = .{.SolidColor = .{.color = .{.r = 0, .g = 1, .b = 1, .a = 1}, .transform = ZRender.Transform2D.Identity}},
    };

    // Yellow triangle
    const triangle3 = ZRender.DrawObject{
        .draws = &[1]ZRender.MeshHandle{mesh},
        .shader = .{.SolidColor = .{.color = .{.r = 1, .g = 1, .b = 0, .a = 1}, .transform = ZRender.Transform2D.Identity}},
    };

    var running = true;
    // main loop
    while(running) {
        // Polls all of the events
        instance.pollEvents();
        // enumerate all of the events
        while(try instance.enumerateEvent()) |event| {
            // If an exit event is signalled on any window, then simply close.
            if(event.event == .exit)running = false;
        }
        
        // submit the trangles to their respective windows
        instance.submitDrawObject(window1, triangle1);
        instance.submitDrawObject(window2, triangle2);
        instance.submitDrawObject(window3, triangle3);

        // You might think that this would cut the framerate by 3 times from vsync
        // but since every window has its own timer for vsync that doesn't actually happen.
        instance.runFrame(window1, .{});
        instance.runFrame(window2, .{});
        instance.runFrame(window3, .{});
    }
}
