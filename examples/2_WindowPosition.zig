// minimal example of using ZRender.

//Import ZRender with default settings.
//ZRender should only be imported from one file,
// then that single import referenced from other files if needed.
const ZRender = @import("zrender").ZRender(.{});
const std = @import("std");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    var allocatorObj = alloc{};
    const allocator = allocatorObj.allocator();
    var v = void{};
    // create an instance with default parameters
    var instance = try ZRender.init(allocator, &v);
    defer instance.deinit();
    // create a window with default settings and debug setup
    _ = instance.initWindow(.{
        .xPos = 100,
        .yPos = 50,
    }, ZRender.debug_setup.makeFake()).?;
    // This runs the instance. It also implicitly ends the lifetimes of all the windows, so be careful with that.
    instance.run();
}