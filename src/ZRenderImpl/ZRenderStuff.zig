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
                // Misc functions

                /// Closes the Instance.
                pub inline fn deinit(this: Interface) void {
                    this.vtable.deinit(this.object);
                }

                /// Returns this instances custom data
                pub inline fn getCustomData(this: Interface) *options.CustomInstanceData {
                    return this.vtable.getCustomData(this.object);
                }

                /// Creates a window. Returns null if something went wrong.
                pub inline fn initWindow(this: Interface, settings: WindowSettings, setup: FakeZRenderSetup) ?*Window {
                    return this.vtable.initWindow(this.object, settings, setup);
                }

                /// Destroyes a window.
                pub inline fn deinitWindow(this: Interface, window: *Window) void {
                    this.vtable.deinitWindow(this.object, window);
                }

                /// Returns a pointer to a windows custom data.
                pub inline fn getCustomWindowData(this: Interface, window: *Window) *options.CustomWindowData {
                    return this.vtable.getCustomWindowData(this.object, window);
                }

                /// Starts the main loop. Returns when there are no open windows.
                pub inline fn run(this: Interface) void {
                    this.vtable.run(this.object);
                }

                // Queue functions
                // TODO: add a general queue that is run whenever is most convenient for the underlying API.

                /// Clears the framebuffer to a solid color.
                pub inline fn clearToColor(this: Interface, queue: *RenderQueue, color: Color) void {
                    this.vtable.clearToColor(this.object, queue, color);
                }

                /// Presents the framebuffer to the window.
                pub inline fn presentFramebuffer(this: Interface, queue: *RenderQueue, vsync: bool) void {
                    this.vtable.presentFramebuffer(this.object, queue, vsync);
                }

                /// Loads a mesh into the GPU. Note that the mesh returned is not loaded immediately, but rather when this queue task runs.
                /// This method does not take ownership of anything. (it copies them)
                pub inline fn loadMesh(this: Interface, queue: *RenderQueue, t: MeshType, hint: MeshUsageHint, attributes: []const MeshAttribute, vertexBuffer: []const u8, indices: []const u32) *Mesh {
                    return this.vtable.loadMesh(this.object, queue, t, hint, attributes, vertexBuffer, indices);
                }

                /// Returns true if a mesh is loaded. Note that queue methods that take a mesh will block until a mesh is loaded,
                /// And methods on the render queue will not actually run until the setup has exited onFrame.
                /// This method is undefined if a mesh is not live (such as if it was unloaded, or the pointer was not created from loadMesh)
                pub inline fn isMeshLoaded(this: Interface, mesh: *Mesh) bool {
                    return this.vtable.isMeshLoaded(this.object, mesh);
                }

                pub inline fn unloadMesh(this: Interface, queue: *RenderQueue, mesh: *Mesh) void {
                    this.vtable.unloadMesh(this.object, queue, mesh);
                }

                /// Replaces the entirety of the vertex buffer and indices of a mesh.
                pub inline fn setMeshData(this: Interface, queue: *RenderQueue, mesh: *Mesh, newVertexBuffer: []const u8, indices: []const u32) void {
                    this.vtable.setMeshData(this.object, queue, mesh, newVertexBuffer, indices);
                }

                /// Replaces a section of the vertex buffer of a mesh. Start is an offset in bytes.
                pub inline fn substituteMeshVertexBuffer(this: Interface, queue: *RenderQueue, mesh: *Mesh, start: usize, vertexBuffer: []const u8) void {
                    this.vtable.substituteMeshVertexBuffer(this.object, queue, mesh, start, vertexBuffer);
                }

                /// replaces a section of he indices of a mesh. Start is an offset index.
                pub inline fn substituteMeshIndices(this: Interface, queue: *RenderQueue, mesh: *Mesh, start: usize, indices: []const u32) void {
                    this.vtable.substituteMeshIndices(this.object, queue, mesh, start, indices);
                }
            };
        }
        pub const Instance = interface.MakeInterface(makeInstance, .{.allow_bitwise_compatibility = true});

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

        /// Mesh usage hint
        pub const MeshUsageHint = enum {
            /// This mesh is used infrequently
            cold,
            /// This mesh is rendered frequently
            render,
            /// this mesh is written to frequently
            write,
            /// This mesh is rendered and written to frequently
            render_write,
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

