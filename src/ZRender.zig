// imports that you don't need to worry about
const std = @import("std");
const stuff = @import("ZRenderImpl/ZRenderStuff.zig");
const gl33 = @import("ZRenderImpl/ZRenderGL33.zig");
// The front-facing API for ZRender.
// None of the actual native implementation is here because otherwise this file would be like 100000 lines long

/// ZRender compile time settings (these are like C macros)
pub const ZRenderOptions = struct {
    // TODO: put some actual settings here
};

// OK I lied, the ACTUAL front facing API is here.
// This is so only one import can give you the entire API rather than having to have @import("ZRender.zig") and another @import(...).ZRender(...)
pub fn ZRender(comptime options: ZRenderOptions) type {
    _ = options;
    return struct {
        pub fn init(allocator: std.mem.Allocator) !stuff.Instance {
            // This is where the API would be chosen, then instantiated.
            // Since the only API currently supported is OpenGL,
            // just return an instance of that.
            return gl33.initInstance(allocator);
        }

        pub const debug_setup = stuff.debug_setup;

        pub const Window = stuff.Window;
    };
}
