const std = @import("std");
const ZRenderOptions = @import("ZRenderOptions.zig");
const interface = @import("interface");

pub fn Stuff (comptime options: ZRenderOptions) type {
    return struct {
        // Stuff that is used by many files
        // Anything you need *SHOULD* be in the ordinary ZRender file. ZRender.zig should be the only file you import.
        // Public types / functions that are in this / other files are exposed through ZRender.zig.

        // This function exists because Instance is an interface created using zig-interface.
        fn makeInstance(comptime Interface: type) type {
            return struct {
                // Functions that you can call
                pub inline fn deinit(this: Interface) void {
                    this.vtable.deinit(this.object);
                }

                pub inline fn getCustomData(this: Interface) options.CustomInstanceData {
                    return this.vtable.getCustomData(this.object);
                }

                pub inline fn initWindow(this: Interface, settings: WindowSettings, setup: FakeZRenderSetup) ?*Window {
                    return this.vtable.initWindow(this.object, settings, setup);
                }

                pub inline fn deinitWindow(this: Interface, window: *Window) void {
                    this.vtable.deinitWindow(this.object, window);
                }

                pub inline fn getCustomWindowData(this: Interface, window: *Window) *options.CustomWindowData {
                    return this.vtable.getCustomWindowData(this.object, window);
                }

                pub inline fn run(this: Interface) void {
                    this.vtable.run(this.object);
                }

                pub inline fn clearToColor(this: Interface, queue: *RenderQueue, color: Color) void {
                    this.vtable.clearToColor(this.object, queue, color);
                }

                pub inline fn presentFramebuffer(this: Interface, queue: *RenderQueue, vsync: bool) void {
                    this.vtable.presentFramebuffer(this.object, queue, vsync);
                }
            };
        }
        pub const Instance = interface.makeInterface(makeInstance, .{.allow_bitwise_compatibility = true});

        /// ZRenderSetup is referenced by the interface, but it references the interface back, causing a circular dependency.
        /// So to break the circular dependency, a non-dependent type is used.
        pub const FakeZRenderSetup = extern struct {
            onRender: *const anyopaque,
            onDeinit: *const anyopaque,
            onEvent: *const anyopaque,
            // this is why custom data has to be a pointer.
            customData: *anyopaque,
        };
        /// a setup is a set of all the callbacks & runtime information of a window.
        /// A user creates a setup, then uses that setup as an argument to creating a window.
        pub const ZRenderSetup = struct {
            /// function callback for each frame.
            /// Delta is in micro seconds
            onRender: *const fn(instance: Instance, window: *Window, queue: *RenderQueue, delta: i64, time: i64) void,
            /// Called right before a window is destroyed.
            onDeinit: *const fn(instance: Instance, window: *Window, time: i64) void,
            /// Event handler. 
            /// All events for all windows are enumerated each frame, before the windows are enumerated for onRender.
            onEvent: *const fn(instance: Instance, window: *Window, event: ZRenderWindowEvent, time: i64) void,
            /// The initial value for the custom window data
            customData: *options.CustomWindowData,

            pub inline fn makeFake(self: ZRenderSetup) FakeZRenderSetup {
                return FakeZRenderSetup{
                    .onRender = self.onRender,
                    .onDeinit = self.onDeinit,
                    .onEvent = self.onEvent,
                    .customData = self.customData,
                };
            }
        };

        pub const ZRenderWindowEvent = union(enum) {
            /// Exit event, for when the window should exit.
            /// The window itself has to do the exiting, ZRender coundn't care less about the meaning of events.
            exit,
            // TODO: most (ideally all) of the events supported by SDL
        };

        
        pub const WindowSettings = struct {
            width: u32 = 800,
            height: u32 = 600,
            name: [:0]const u8 = "ZRender window",
            yPos: ?u32 = null,
            xPos: ?u32 = null,
            resizable: bool = false,
        };

        /// The actual window is implemented by the instance.
        /// an instance of a window is given to a function called from the instance,
        /// and the instance can treat the window as any object with the size of a pointer.
        pub const Window = opaque{};

        /// The actual render queue is implemented by the instance.
        /// The render queue is given as an argument to instance functions.
        pub const RenderQueue = opaque{};

        // GPU objects

        // TODO: It might be worth supporting non-indexed vertex arrays? Probably not though.
        /// A mesh. Can be either a triangle mesh or a quad mesh.
        /// The actual mesh type is implemented by the instance, use instance functions on it.
        pub const Mesh = opaque{};

        /// Mesh type
        pub const MeshType = enum {
            triangles, quads,
        };

        /// Mesh attribute
        pub const MeshAttribute = enum {
            // base types
            /// Boolean value
            @"bool",
            /// 32 bit signed twos-compliment integer
            int,
            /// 32 bit unsigned integer
            uint,
            /// 32 bit IEEE-754 float
            float,
            // 2D vectors
            /// vector of two bools
            bvec2,
            /// vector of two ints
            ivec2,
            /// vector of two uints
            uvec2,
            /// vector of two floats
            vec2,
            // 3D vectors
            /// vector of three bools
            bvec3,
            /// vector of three ints
            ivec3,
            /// vector of three uints
            uvec3,
            /// vector of three floats
            vec3,
            // 4D vectors
            /// vector of four bools
            bvec4,
            /// vector of four ints
            ivec4,
            /// vector of four uints
            uvec4,
            /// vector of four floats
            vec4,
        };

        pub const Color = struct {
            r: u8,
            g: u8,
            b: u8,
            a: u8,
        };

        // a pre-made setup for the hello world example
        fn debugSetupOnRender(instance: Instance, window: *Window, queue: *RenderQueue, delta: i64, time: i64) void {
            _ = delta;
            _ = window;
            instance.clearToColor(queue, .{.r = 255, .g = @intCast(@divFloor(time * 255, std.time.us_per_s * 10) & 255), .b = 255, .a = 255});
            instance.presentFramebuffer(queue, true);
        }

        fn debugSetupOnDeinit(instance: Instance, window: *Window, time: i64) void {
            _ = time;
            _ = instance;
            std.debug.print("Window {} destroyed.\n", .{window});
        }

        fn debugSetupOnEvent(instance: Instance, window: *Window, event: ZRenderWindowEvent, time: i64) void {
            _ = time;
            switch (event) {
                .exit => instance.deinitWindow(window),
            }
        }
        /// A pre-made setup that can be used to see if the library is working at a basic level.
        /// Will only work if the custom window data is void.
        pub const debug_setup = ZRenderSetup {
            .onRender = &debugSetupOnRender,
            .onDeinit = &debugSetupOnDeinit,
            .onEvent = &debugSetupOnEvent,
            .customData = @constCast(&void{}),
        };
    };
}

