const std = @import("std");
const gl = @import("ext/GL33Bind.zig");
const sdl = @import("sdl");
const ZRenderOptions = @import("ZRenderOptions.zig");

fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
    _ = ctx;
    return sdl.gl.getProcAddress(name);
}
pub fn ZRenderGL33(comptime options: ZRenderOptions) type {
    return struct {
        const stuff = @import("ZRenderStuff.zig").Stuff(options);
        // some 'static includes' because yeah
        const Instance = stuff.Instance;
        const Window = stuff.Window;
        pub fn initInstance(allocator: std.mem.Allocator, initialCustomData: options.CustomInstanceData) !Instance {
            
            try sdl.init(.{.video = true});
            var obj = ZRenderGL33Instance{
                .allocator = allocator,
                .windows = std.ArrayList(*ZRenderGL33Window).init(allocator),
                .newWindows = std.ArrayList(*ZRenderGL33Window).init(allocator),
                .windowsToDeinit = std.ArrayList(*ZRenderGL33Window).init(allocator),
                .context = null,
                .customData = initialCustomData,
            };
            var object = try allocator.create(ZRenderGL33Instance);
            object.* = obj;
            const vtable = stuff.ZRenderInstanceVTable {
                .deinit = &ZRenderGL33Instance.deinit,
                .getCustomData = &ZRenderGL33Instance.getCustomData,
                .initWindow = &ZRenderGL33Instance.initWindow,
                .deinitWindow = &ZRenderGL33Instance.deinitWindow,
                .getCustomWindowData = &ZRenderGL33Instance.getCustomWindowData,
                .run = &ZRenderGL33Instance.run,
                .clearToColor = &ZRenderGL33Instance.clearToColor,
                .presentFramebuffer = &ZRenderGL33Instance.presentFramebuffer,
            };
            return Instance {
                .object = object,
                .vtable = &vtable,
            };
        }

        const ZRenderGL33Instance = struct {
            allocator: std.mem.Allocator,
            context: ?sdl.gl.Context,
            windows: std.ArrayList(*ZRenderGL33Window),
            // Windows that have been created but not added to the list of windows
            newWindows: std.ArrayList(*ZRenderGL33Window),
            // Windows that have been queued to be deleted.
            windowsToDeinit: std.ArrayList(*ZRenderGL33Window),

            customData: options.CustomInstanceData,

            pub fn deinit(instance: Instance) void {
                var this = _this(instance);
                this.windows.deinit();
                this.newWindows.deinit();
                this.windowsToDeinit.deinit();
                sdl.quit();
                this.allocator.destroy(this);
            }

            pub fn getCustomData(instance: Instance) options.CustomInstanceData {
                var this = _this(instance);
                return this.customData;
            }

            fn initWindow(instance: Instance, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) ?*Window {
                var this = _this(instance);
                var window = ZRenderGL33Window.init(this.allocator, settings, setup) catch |e| {
                    std.io.getStdErr().writer().print("Error creating window: {s}", .{@errorName(e)}) catch return null;
                    return null;
                };
                this.newWindows.append(window) catch return null;
                // If there isn't already an initialized context, initialize it.
                
                // Because OpenGL is stupid and annoying, it HAS to be attached to a window,
                // which is why it is initialized after the window, not before.
                if(this.context == null) {
                    this.context = sdl.gl.createContext(window.sdlWindow) catch return null;
                    gl.load(void{}, loadProc) catch return null;
                }
                return @as(*Window, @ptrCast(window));
            }

            pub fn deinitWindow(instance: Instance, window_uncast: *Window) void {
                var this = _this(instance);
                var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
                this.windowsToDeinit.append(window) catch unreachable;
            }

            pub fn getCustomWindowData(instance: Instance, window_uncast: *Window) options.CustomWindowData {
                _ = instance;
                var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
                return window.setup.customData;
            }

            fn actuallyDeinitWindow(instance: Instance, window: *ZRenderGL33Window) void {
                var this = _this(instance);
                // remove the window from the list
                for(this.windows.items, 0..) |window_item, window_index| {
                    if(window_item == window) {
                        _ = this.windows.swapRemove(window_index);
                        break;
                    }
                }
                // deinit the draw queue
                window.queue.deinit();
                // If this was the last window, destroy the OpenGL context as well
                if(this.windows.items.len == 0){
                    sdl.gl.deleteContext(this.context.?);
                }
                window.sdlWindow.destroy();
                // Actually delete the window object
                this.allocator.destroy(window);
            }

            pub fn run(instance: Instance) void {
                var this = _this(instance);
                var lastFrameTime = std.time.microTimestamp();
                var currentFrameTime = lastFrameTime;

                mainloop: while(true) {
                    while(sdl.pollEvent()) |event| {
                        // TODO: send events to windows.
                        // I also think it might be worth making the window in charge of calling deinit when it recieves a close event
                        switch (event) {
                            .quit => {
                                actuallyDeinitWindow(instance, this.windows.items[0]);
                                break :mainloop;
                            },
                            .window => |windowEvent| {
                                switch (windowEvent.type) {
                                    .close => {
                                        const id = windowEvent.window_id;
                                        if(sdl.Window.fromID(id)) |sdlWindow| {
                                            // Find the actual ZRender window
                                            for(this.windows.items) |window| {
                                                if(window.sdlWindow.ptr == sdlWindow.ptr) {
                                                    // Now that we have the ZRender window we can actually deinit it
                                                    this.windowsToDeinit.append(window) catch unreachable;
                                                }
                                            }
                                        }
                                    },
                                    else => {},
                                }
                            },
                            else => {},
                        }
                    }
                    // Go through the windows that need to be (de)initialized
                    for(this.windowsToDeinit.items) |windowToDeinit| {
                        windowToDeinit.setup.onDeinit(instance, @ptrCast(windowToDeinit), currentFrameTime);
                        actuallyDeinitWindow(instance, windowToDeinit);
                    }
                    this.windowsToDeinit.clearRetainingCapacity();
                    for(this.newWindows.items) |newWindow| {
                        this.windows.append(newWindow) catch unreachable;
                    }
                    this.newWindows.clearRetainingCapacity();
                    currentFrameTime = std.time.microTimestamp();
                    const delta = currentFrameTime - lastFrameTime;
                    for(this.windows.items) |window| {
                        window.setup.onRender(instance, @ptrCast(window), @ptrCast(&window.queue), delta, currentFrameTime);
                        // TODO: actually run the queue asynchronously
                        // Or at least run it after all of the windows are finished being iterated.

                        // TODO: verify that this function actually flushes the OpenGL command queue
                        // TODO: it might be worth rendering to a bunch of render buffers, then blitting it to the windows,
                        //  In order to avoid synchronization between the GPU and CPU while the GPU is doing real work,
                        //  However I am not sure if that would actually improve performance so it should be properly tested
                        sdl.gl.makeCurrent(this.context.?, window.sdlWindow) catch @panic("Failed to make window current!");
                        window.queue.run(window);
                    }
                    lastFrameTime = currentFrameTime;
                }
            }

            pub fn clearToColor(instance: Instance, renderQueueUncast: *stuff.RenderQueue, color: stuff.Color) void {
                _ = instance;
                var renderQueue: *GL33RenderQueue = @alignCast(@ptrCast(renderQueueUncast));
                renderQueue.items.append(.{
                    .clearToColor = color,
                }) catch unreachable;
            }

            pub fn presentFramebuffer(instance: Instance, renderQueueUncast: *stuff.RenderQueue, vsync: bool) void {
                _ = instance;
                var renderQueue: *GL33RenderQueue = @alignCast(@ptrCast(renderQueueUncast));
                renderQueue.items.append(.{
                    .presentFramebuffer = vsync,
                }) catch unreachable;
            }

            inline fn _this(instance: Instance) *@This() {
                return @alignCast(@ptrCast(instance.object));
            }
        };

        const ZRenderGL33Window = struct {
            sdlWindow: sdl.Window,
            setup: stuff.ZRenderSetup,
            queue: GL33RenderQueue,

            pub fn init(allocator: std.mem.Allocator, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) !*ZRenderGL33Window {
                const xPos:sdl.WindowPosition = blk: {
                    if(settings.xPos == null) break :blk .default
                    else break :blk .{.absolute = @intCast(settings.xPos.?)};
                };
                const yPos:sdl.WindowPosition = blk: {
                    if(settings.yPos == null) break :blk .default
                    else break :blk .{.absolute = @intCast(settings.yPos.?)};
                };
                const w = ZRenderGL33Window{
                    .sdlWindow = try sdl.createWindow(settings.name, xPos, yPos, @intCast(settings.width), @intCast(settings.height), .{
                        .resizable = settings.resizable,
                        .context = .opengl,
                    }),
                    .setup = setup,
                    .queue = GL33RenderQueue.init(allocator),
                };
                var object = try allocator.create(ZRenderGL33Window);
                object.* = w;
                return object;
            }
        };

        const GL33RenderQueueItem = union(enum) {
            clearToColor: stuff.Color,
            /// the bool is vsync
            presentFramebuffer: bool,
        };

        const GL33RenderQueue = struct {
            // TODO: use a dependency tree instead of a list
            // TODO: (far future) optimize queue items a bit, such as combining overlapping clears.
            items: std.ArrayList(GL33RenderQueueItem),
            
            pub fn init(allocator: std.mem.Allocator) @This() {
                return @This() {
                    .items = std.ArrayList(GL33RenderQueueItem).init(allocator),
                };
            }

            pub fn deinit(this: @This()) void {
                this.items.deinit();
            }

            /// Runs the queue on the current OpenGL context and window, then clears the queue.
            pub fn run(this: *@This(), window: *ZRenderGL33Window) void {
                for(this.items.items) |item| {
                    switch (item) {
                        .clearToColor => |color| {
                            gl.clearColor(@as(f32, @floatFromInt(color.r)) / 256.0, @as(f32,@floatFromInt(color.g)) / 256.0, @as(f32, @floatFromInt(color.b)) / 256.0, @as(f32, @floatFromInt(color.a)) / 256.0);
                            gl.clear(gl.COLOR_BUFFER_BIT);
                        },
                        .presentFramebuffer => |vsync| {
                            if(vsync) {
                                sdl.gl.setSwapInterval(.adaptive_vsync) catch @panic("Could not set swap interval to adaptive sync");
                            } else {
                                sdl.gl.setSwapInterval(.immediate) catch @panic("Could not set swap interval to immediate");
                            }
                            sdl.gl.swapWindow(window.sdlWindow);
                        }
                    }
                }
                this.items.clearRetainingCapacity();
            }
        };
    };
}