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

    pub fn deinit(instance: Instance) void {
        _ = instance;
        sdl.quit();
    }
    
    pub fn initWindow(instance: Instance, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) ?*Window {
        var this: *@This() = @alignCast(@ptrCast(instance.object));
        var window = ZRenderGL33Window.init(this.allocator, settings, setup) catch |e| {
            std.io.getStdErr().writer().print("Error creating window: {s}", .{@errorName(e)}) catch return null;
            return null;
        };
        this.windows.append(window) catch return null;
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
        var this: *ZRenderGL33Instance = @alignCast(@ptrCast(instance.object));
        var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
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
        var this: *@This() = @alignCast(@ptrCast(instance.object));
        var lastFrameTime = std.time.microTimestamp();
        var currentFrameTime = lastFrameTime;

        mainloop: while(true) {
            while(sdl.pollEvent()) |event| {
                switch (event) {
                    // This is the event for if there is only one window
                    .quit => break :mainloop,
                    // TODO: only quit the window that the event came from
                    .window => |windowEvent| {
                        switch (windowEvent.type) {
                            .close => break :mainloop,
                            else => {},
                        }
                    },
                    else => {},
                }
            }
            currentFrameTime = std.time.microTimestamp();
            const delta = currentFrameTime - lastFrameTime;
            // TODO: handle when windows are added or removed during the main loop
            // An easy way to do this would be to keep track of a list of window changes
            // (with instance.initWindow and instance.deinitWindow)
            // then iterate that list after the windows are all iterated.
            for(this.windows.items) |window| {
                window.setup.onRender(instance, @ptrCast(window), @ptrCast(&window.queue), delta, currentFrameTime);
                // TODO: actually run the queue asynchronously

                // TODO: verify that this function actually flushes the OpenGL command queue
                sdl.gl.makeCurrent(this.context.?, window.sdlWindow) catch @panic("Failed to make window current!");
                window.queue.run();
                // Not sure why, but I have to set the vsync EVERY frame, or else it won't work correctly
                sdl.gl.setSwapInterval(.adaptive_vsync) catch unreachable;
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
        }) catch unreachable;
    }
};

const ZRenderGL33Window = struct {
    sdlWindow: sdl.Window,
    setup: stuff.ZRenderSetup,
    queue: GL33RenderQueue,

    pub fn init(allocator: std.mem.Allocator, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) !*ZRenderGL33Window {
        const w = ZRenderGL33Window{
            // TODO: monitor
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