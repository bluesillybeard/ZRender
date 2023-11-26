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
        // TODO: multiple windows
        var this: *@This() = @alignCast(@ptrCast(instance.object));
        var window = ZRenderGL33Window.init(this.allocator, settings, setup) catch |e| {
            std.io.getStdErr().writer().print("Error creating window: {s}", .{@errorName(e)}) catch return null;
            return null;
        };
        this.windows.append(window) catch return null;
        if(this.context == null) {
            this.context = sdl.gl.createContext(window.sdlWindow) catch return null;
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
        window.sdlWindow.destroy();
    }

    pub fn run(instance: Instance) void {
        var this: *@This() = @alignCast(@ptrCast(instance.object));
        // TODO: multiple windows
        var window: *ZRenderGL33Window = this.windows.items[0];
        var lastFrameTime = std.time.microTimestamp();
        var currentFrameTime = lastFrameTime;

        mainloop: while(true) { //windowShouldClose
            // TODO: poll events once per frame
            // instead of once per window per frame
            while(sdl.pollEvent()) |event| {
                switch (event) {
                    .quit => break :mainloop,
                    else => {},
                }
            }
            currentFrameTime = std.time.microTimestamp();
            window.setup.onRender(instance, @ptrCast(window), @ptrCast(&window.queue), currentFrameTime - lastFrameTime);
            // TODO: actually run the queue asynchronously
            window.queue.run();
            lastFrameTime = currentFrameTime;
            sdl.gl.swapWindow(window.sdlWindow);
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