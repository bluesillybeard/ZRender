// minimal example of using ZRender.

//Import ZRender with default settings.
//ZRender should only be imported from one file,
// then that single import referenced from other files if needed.
const ZRender = @import("zrender").ZRender(.{});
const std = @import("std");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    std.debug.print("This is the windows example!", .{});
    var allocatorObj = alloc{};
    var allocator = allocatorObj.allocator();
    // create an instance with default parameters
    var instance = try ZRender.init(allocator);
    defer instance.deinit();
    // create a window with default settings and debug setup
    var window = instance.initWindow(.{
            .name = "Window number 1",
        },
        ZRender.debug_setup).?;
    defer instance.deinitWindow(window);
    // Run the window. This also ends the window's lifetime since it's intended to be the last function run on a default window.
    instance.run();
}