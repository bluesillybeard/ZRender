const std = @import("std");
const ZRender = @import("zrender");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();
    // Create instance with default options
    var instance = try ZRender.initInstance(.{.allocator = allocator});
    // Since the instance's lifetime is the same as this scope, a defer is used
    defer instance.deinit();

    // Create window with default options
    const window = try instance.createWindow(.{});
    // The window must be destroyed before the instance
    defer instance.deinitWindow(window);
    
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

        // This function would run all of the draw lists submitted to it, if we had actually submited any,
        // Then it presents the frame buffer (and does a few other things)
        instance.runFrame(window, .{});
    }
}
