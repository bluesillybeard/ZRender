const std = @import("std");
const ZRenderOptions = @import("ZRenderOptions.zig");

pub fn Stuff (comptime options: ZRenderOptions) type {
    return struct {
        // Stuff that is used by many files
        // Anything you need *SHOULD* be in the ordinary ZRender file. ZRender.zig should be the only file you import.
        // Public types / functions that are in this / other files are exposed through ZRender.zig.

        /// Instance is a Rust-like dynamic reference,
        /// where the vtable is part of a wide pointer instead of being in the object itself.
        /// Every ZRender function (with a few exceptions) is called from the instance.
        /// I recomend either passing the instance through functions or making it a singleton.
        pub const Instance = struct {
            vtable: *const ZRenderInstanceVTable,
            object: *anyopaque,
            
            //TODO: DO NOT TRY TO either generate these functions from the vtable, or vice-versa.
            // YOU WILL LOOSE YOU MIND AND GO INSANE
            // I nearly went monkey brain dingus death mode
            // and commited crimes or something
            // because I wasted like 5 hours
            // on doing that And nearly went
            // complete bonkers hyper dingus brain
            // idiot mega smooth shiny zombie ding dong
            // bing bong coopy doopy poop
            // I need to sleep before my brain dies.

            // That is one benefit of C++ - dynamic dispatch
            // is done for you and is very easy.

            // OK so because I value my mental health
            // ok well maybe i don't but whatever
            // lok at these at some point:
            // https://github.com/alexnask/interface.zig
            // 

            // Also a good idea would be to just use a blooming enum(union)
            // instead of this OOP approach
            // but that itself has quite a few downsides
            // such as making it harder / nearly impossible for mods to add their own custom renderers
            // like what Minecraft's Optifine does.

            pub inline fn deinit(this: @This()) void {
                this.vtable.deinit(this);
            }

            pub inline fn getCustomData(this: @This()) options.CustomInstanceData {
                return this.vtable.getCustomData(this);
            }
            
            pub inline fn initWindow(this: @This(), settings: WindowSettings, setup: ZRenderSetup) ?*Window {
                return this.vtable.initWindow(this, settings, setup);
            }

            pub inline fn deinitWindow(this: @This(), window: *Window) void {
                this.vtable.deinitWindow(this, window);
            }

            pub inline fn getCustomWindowData(this: @This(), window: *Window) options.CustomWindowData {
                return this.vtable.getCustomWindowData(this, window);
            }

            pub inline fn run(this: @This()) void {
                this.vtable.run(this);    
            }

            pub inline fn clearToColor(this: @This(), queue: *RenderQueue, color: Color) void {
                this.vtable.clearToColor(this, queue, color);
            }

            pub inline fn presentFramebuffer(this: @This(), queue: *RenderQueue, vsync: bool) void {
                this.vtable.presentFramebuffer(this, queue, vsync);
            }
        };

        pub const ZRenderInstanceVTable = struct {
            deinit: *const fn(instance: Instance) void,
            getCustomData: *const fn(instance: Instance) options.CustomInstanceData,
            initWindow: *const fn(instance: Instance, settings: WindowSettings, setup: ZRenderSetup) ?*Window,
            deinitWindow: *const fn(instance: Instance, window: *Window) void,
            getCustomWindowData: *const fn(instance: Instance, window: *Window) options.CustomWindowData,
            run: *const fn(instance: Instance) void,
            clearToColor: *const fn (instance: Instance, renderQueue: *RenderQueue, color: Color) void,
            presentFramebuffer: *const fn (instance: Instance, RenderQueue: *RenderQueue, vsync: bool) void,
        };

        pub const ZRenderWindowEvent = union(enum) {
            /// Exit event, for when the window should exit.
            /// The window itself has to do the exiting, ZRender coundn't care less about the meaning of events.
            exit,
            // TODO: most (ideally all) of the events supported by SDL
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
            customData: options.CustomWindowData,
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
            .customData = void{},
        };
    };
}

