// minimal example of using ZRender.

//Import ZRender with default settings.
//ZRender should only be imported from one file,
// then that single import referenced from other files if needed.
const ZRender = @import("zrender").ZRender(.{});
const std = @import("std");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var allocatorObj = alloc{};
    var allocator = allocatorObj.allocator();
    // create an instance with default parameters
    var instance = try ZRender.init(allocator);
    defer instance.deinit();
    // create a window with default settings and debug setup
    var window = instance.initWindow(.{}, ZRender.debug_setup).?;
    defer instance.deinitWindow(window);
    // Run the program. When run() exits, it means that the program is done running.
    instance.run();
}