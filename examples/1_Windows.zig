// minimal example of using ZRender.

//Import ZRender with default settings.
//ZRender should only be imported from one file,
// then that single import referenced from other files if needed.
const ZRender = @import("zrender").ZRender(.{});
const std = @import("std");
const alloc = std.heap.GeneralPurposeAllocator(.{});

const numWindows = 20;

pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();
    var instance = try ZRender.init(allocator, void{});
    defer instance.deinit();
    // create a bunch of windows
    var windows = std.ArrayList(*ZRender.Window).init(allocator);
    inline for(0..numWindows) |index| {
        var indexStrBuffer: [100:0] u8 = undefined;
        const name = try std.fmt.bufPrint(&indexStrBuffer, "Window number {d}", .{index});
        indexStrBuffer[name.len] = 0;
        const window = instance.initWindow(.{
            .name =  &indexStrBuffer,
        }, ZRender.debug_setup) orelse @panic("Could not create window");
        windows.append(window) catch unreachable;
    }
    defer windows.deinit();
    instance.run();
}