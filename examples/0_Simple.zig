// minimal example of using ZRender.

//Import ZRender with default settings.
//ZRender should only be imported from one file,
// then that single import referenced from other files if needed.
const ZRender = @import("zrender").ZRender(.{});
const std = @import("std");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    var allocator = allocatorObj.allocator();
    // create an instance with default parameters
    var instance = try ZRender.init(allocator, void{});
    defer instance.deinit();
    // create a window with default settings and debug setup
    _ = instance.initWindow(.{}, ZRender.debug_setup).?;
    // This runs the instance. It also implicitly ends the lifetimes of all the windows, so be careful with that.
    instance.run();
}