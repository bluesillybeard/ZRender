const std = @import("std");
const stuff = @import("ZRenderStuff.zig");
const gl = @import("ext/GL33Bind.zig");
const glfw = @import("ext/zglfw.zig");

// some 'static includes' because yeah
const Instance = stuff.Instance;
const Window = stuff.Window;

fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
    _ = ctx;
    return glfw.getProcAddress(name);
}

pub fn initInstance(allocator: std.mem.Allocator) !Instance {
    // Before we create the object, initialize GLFW.
    try glfw.init();
    var obj = ZRenderGL33Instance{
        .allocator = allocator,
    };
    var object = try allocator.create(ZRenderGL33Instance);
    object.* = obj;
    const vtable = stuff.ZRenderInstanceVTable {
        .deinit = &ZRenderGL33Instance.deinit,
        .initWindow = &ZRenderGL33Instance.initWindow,
        .deinitWindow = &ZRenderGL33Instance.deinitWindow,
        .runWindow = &ZRenderGL33Instance.runWindow,
        .clearToColor = &ZRenderGL33Instance.clearToColor,
    };
    return Instance {
        .object = object,
        .vtable = &vtable,
    };
}

const ZRenderGL33Instance = struct {
    allocator: std.mem.Allocator,

    pub fn deinit(instance: Instance) void {
        // There isn't a lot to deinit in OpenGL
        // since the context is destroyed with the last window.
        _ = instance;
    }
    
    pub fn initWindow(instance: Instance, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) ?*Window {
        // TODO: multiple windows
        var this: *@This() = @alignCast(@ptrCast(instance.object));
        var window = ZRenderGL33Window.init(this.allocator, settings, setup) catch |e| {
            std.io.getStdErr().writer().print("Error creating window: {s}", .{@errorName(e)}) catch return null;
            return null;
        };
        return @as(*Window, @ptrCast(window));
    }

    pub fn deinitWindow(instance: Instance, window_uncast: *Window) void {
        _ = instance;
        var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
        glfw.destroyWindow(window.glfwWindow);
    }

    // TODO: it might be worth replacing this with just 'run' that doesn't differentiate between windows.
    pub fn runWindow(instance: Instance, window_uncast: *Window) void {
        //var this: *@This() = @alignCast(@ptrCast(instance.object));
        var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
        var lastFrameTime = std.time.microTimestamp();
        var currentFrameTime = lastFrameTime;
        while(!glfw.windowShouldClose(window.glfwWindow)) {
            // TODO: poll events once per frame
            // instead of once per window per frame
            glfw.pollEvents();
            currentFrameTime = std.time.microTimestamp();
            window.setup.onRender(instance, window_uncast, @ptrCast(&window.queue), currentFrameTime - lastFrameTime);
            // TODO: actually run the queue asynchronously
            window.queue.run();
            lastFrameTime = currentFrameTime;
            glfw.swapBuffers(window.glfwWindow);
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
    glfwWindow: *glfw.Window,
    setup: stuff.ZRenderSetup,
    queue: GL33RenderQueue,

    pub fn init(allocator: std.mem.Allocator, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) !*ZRenderGL33Window {
        const w = ZRenderGL33Window{
            // TODO: monitor
            .glfwWindow = try glfw.createWindow(@as(c_int, @intCast(settings.width)), @as(c_int, @intCast(settings.height)), settings.name, null, null),
            .setup = setup,
            .queue = GL33RenderQueue.init(allocator),
        };
        glfw.makeContextCurrent(w.glfwWindow);
        // GLFW needs an OpenGL context to load procs for some reason so yeah
        try gl.load(void{}, loadProc);
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