const std = @import("std");
const stuff = @import("ZRenderStuff.zig");
const gl = @import("ext/GL33Bind.zig");
const c = @cImport({
    @cInclude("GL/glew.h");
});
const sdl = @import("sdl");

// some 'static includes' because yeah
const Instance = stuff.Instance;
const Window = stuff.Window;

fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
    _ = ctx;
    return sdl.gl.getProcAddress(name);
}

pub fn initInstance(allocator: std.mem.Allocator) !Instance {
    
    try sdl.init(.{.video = true});
    var obj = ZRenderGL33Instance{
        .allocator = allocator,
        .windows = std.ArrayList(*ZRenderGL33Window).init(allocator),
        .newWindows = std.ArrayList(*ZRenderGL33Window).init(allocator),
        .windowsToDeinit = std.ArrayList(*ZRenderGL33Window).init(allocator),
        .context = null,
    };
    var object = try allocator.create(ZRenderGL33Instance);
    object.* = obj;
    const vtable = stuff.ZRenderInstanceVTable {
        .deinit = &ZRenderGL33Instance.deinit,
        .initWindow = &ZRenderGL33Instance.initWindow,
        .deinitWindow = &ZRenderGL33Instance.deinitWindow,
        .run = &ZRenderGL33Instance.run,
        .clearToColor = &ZRenderGL33Instance.clearToColor,
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

    pub fn deinit(instance: Instance) void {
        var this = _this(instance);
        this.windows.deinit();
        this.newWindows.deinit();
        this.windowsToDeinit.deinit();
        sdl.quit();
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
            // TODO: test if this actually requires a context. It probably does but may as well test it.
            gl.load(void{}, loadProc) catch return null;
        }
        return @as(*Window, @ptrCast(window));
    }

    pub fn deinitWindow(instance: Instance, window_uncast: *Window) void {
        var this = _this(instance);
        var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
        this.windowsToDeinit.append(window) catch unreachable;
    }

    fn actuallyDeinitWindow(instance: Instance, window: *ZRenderGL33Window) void {
        var this = _this(instance);
        for(this.windows.items, 0..) |window_item, window_index| {
            if(window_item == window) {
                _ = this.windows.swapRemove(window_index);
                break;
            }
        }
        // If this was the last window, destroy the OpenGL context as well
        if(this.windows.items.len == 0){
            sdl.gl.deleteContext(this.context.?);
        }
        window.sdlWindow.destroy();
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
                    .quit => break :mainloop,
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
                actuallyDeinitWindow(instance, windowToDeinit);
                // TODO: callback in window setup for before a window is destroyed
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
                window.queue.run();
                // Not sure why, but I have to set the vsync EVERY frame, or else it won't work correctly
                // TODO: make the frame presentation a command instead of automatic, for the use case of mixing event mode and immediate mode windows.
                sdl.gl.setSwapInterval(.adaptive_vsync) catch @panic("Could not set swap interval to adaptive sync");
                sdl.gl.swapWindow(window.sdlWindow);
            }
            lastFrameTime = currentFrameTime;
        }
    }

    pub fn clearToColor(instance: Instance, renderQueueUncast: *stuff.RenderQueue, color: stuff.Color) void {
        _ = instance;
        var renderQueue: *GL33RenderQueue = @alignCast(@ptrCast(renderQueueUncast));
        renderQueue.items.append(GL33RenderQueueItem{
            .clearToColor = color,
        }) catch @panic("Could not append ClearToColor to render queue");
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
        const w = ZRenderGL33Window{
            // TODO: window position
            .sdlWindow = try sdl.createWindow(settings.name, .default, .default, @intCast(settings.width), @intCast(settings.height), .{
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

const GL33UninitializedWindow = struct {
    settings: stuff.WindowSettings,
    setup: stuff.ZRenderSetup,
};

const GL33RenderQueueItem = union(enum) {
    clearToColor: stuff.Color,
};

const GL33RenderQueue = struct {
    // TODO: use a dependency tree instead of a list
    items: std.ArrayList(GL33RenderQueueItem),
    
    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This() {
            .items = std.ArrayList(GL33RenderQueueItem).init(allocator),
        };
    }

    pub fn deinit(this: @This()) void {
        this.items.deinit();
    }

    /// Runs the queue on the current OpenGL context and window, then clears it.
    pub fn run(this: *@This()) void {
        for(this.items.items) |item| {
            switch (item) {
                .clearToColor => |color| {
                    gl.clearColor(@as(f32, @floatFromInt(color.r)) / 256.0, @as(f32,@floatFromInt(color.g)) / 256.0, @as(f32, @floatFromInt(color.b)) / 256.0, @as(f32, @floatFromInt(color.a)) / 256.0);
                    gl.clear(gl.COLOR_BUFFER_BIT);
                },
            }
        }
        this.items.clearRetainingCapacity();
    }
};