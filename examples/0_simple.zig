const ZRender = @import("zrender");

pub fn main() !void {
    // Create instance with default options
    var instance = try ZRender.initInstance(.{});
    // Since the instance's lifetime is the same as this scope, a defer is used
    defer instance.deinit();

    // Create window with default options
    var window = try instance.createWindow(.{});
    // The window must be destroyed before the instance
    defer instance.deinitWindow(window);
    
    var running = true;
    // main loop
    while(running) {
        // Polls all of the events
        instance.PollEvents();
        // enumerate all of the events
        while(instance.enumerateEvent()) |event| {
            // If an exit event is signalled, then we should close.
            if(event == .exit) running = false;
        }

        // This function would run all of the draw lists submitted to it, if we had actually submited any,
        // Then it presents the frame buffer (and does a few other things)
        window.runFrame(.{});
    }
}
