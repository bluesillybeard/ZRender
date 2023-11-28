// imports that you don't need to worry about
const std = @import("std");
// The front-facing API for ZRender.
// None of the actual native implementation is here because otherwise this file would be like 100000 lines long

pub const ZRenderOptions = @import("ZRenderImpl/ZRenderOptions.zig");

// OK I lied, the ACTUAL front facing API is here.
// This is so only one import can give you the entire API rather than having to have @import("ZRender.zig") and another @import(...).ZRender(...)
pub fn ZRender(comptime options: ZRenderOptions) type {
    return struct {
        pub const Window = stuff.Window;

        pub const Instance = stuff.Instance;
        pub fn init(allocator: std.mem.Allocator, initialCustomData: options.CustomInstanceData) !Instance {
            // This is where the API would be chosen, then instantiated.
            // Since the only API currently supported is OpenGL,
            // just return an instance of that.
            return gl33.initInstance(allocator, initialCustomData);
        }

        pub const debug_setup = stuff.debug_setup;

        // Things you don't need to worry about

        const stuff = @import("ZRenderImpl/ZRenderStuff.zig").Stuff(options);
        const gl33 = @import("ZRenderImpl/ZRenderGL33.zig").ZRenderGL33(options);
    };
}
