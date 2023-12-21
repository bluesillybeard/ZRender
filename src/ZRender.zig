// imports that you don't need to worry about
const std = @import("std");
// The front-facing API for ZRender.
// None of the actual native implementation is here because otherwise this file would be like 100000 lines long

pub const ZRenderOptions = @import("ZRenderImpl/ZRenderOptions.zig");

// OK I lied, the ACTUAL front facing API is here.
// This is so only one import can give you the entire API rather than having to have @import("ZRender.zig") and another @import(...).ZRender(...)
pub fn ZRender(comptime options: ZRenderOptions) type {
    return struct {
        pub const Instance = stuff.Instance;

        /// Creates an instance.
        pub fn init(allocator: std.mem.Allocator, customData: *options.CustomInstanceData) !Instance {
            // This is where the API would be chosen, then instantiated.
            // Since the only API currently supported is OpenGL,
            // just return an instance of that.
            return gl41.initInstance(allocator, customData);
        }

        // A bunch of stuff in no particular order
        pub const ZRenderSetup = stuff.ZRenderSetup;
        pub const Color = stuff.Color;
        pub const Mesh = stuff.Mesh;
        pub const MeshAttribute = stuff.MeshAttribute;
        pub const MeshType = stuff.MeshType;
        pub const MeshUsageHint = stuff.MeshUsageHint;
        pub const RenderQueue = stuff.RenderQueue;
        pub const Window = stuff.Window;
        pub const WindowSettings = stuff.WindowSettings;
        pub const ZRenderWindowEvent = stuff.ZRenderWindowEvent;

        pub const debug_setup = stuff.debug_setup;

        // Things you don't need to worry about

        const stuff = @import("ZRenderImpl/ZRenderStuff.zig").Stuff(options);
        const gl41 = @import("ZRenderImpl/ZRenderGL41.zig").ZRenderGL41(options);
    };
}
