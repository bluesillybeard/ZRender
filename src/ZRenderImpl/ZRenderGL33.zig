const std = @import("std");
const stuff = @import("ZRenderStuff.zig");
const gl = @import("ext/GL33Bind.zig");
const glfw = @import("ext/zglfw.zig");

// some 'static includes' because yeah
const Instance = stuff.Instance;

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
    
    pub fn initWindow(instance: Instance, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) ?*stuff.Window {
        // TODO: multiple windows
        var this: *@This() = @alignCast(@ptrCast(instance.object));
        var window = ZRenderGL33Window {
            // TODO: monitor
            .glfwWindow = glfw.createWindow(@as(c_int, @intCast(settings.width)), @as(c_int, @intCast(settings.height)), settings.name, null, null) catch return null,
            .setup = setup,
        };
        glfw.makeContextCurrent(window.glfwWindow);
        // GLFW needs an OpenGL context to load procs for some reason so yeah
        gl.load(void{}, loadProc) catch return null;
        var object = this.allocator.create(ZRenderGL33Window) catch return null;
        object.* = window;
        return @as(*stuff.Window, @ptrCast(object));
    }

    pub fn deinitWindow(instance: Instance, window_uncast: *stuff.Window) void {
        _ = instance;
        var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
        glfw.destroyWindow(window.glfwWindow);
    }

    pub fn runWindow(instance: Instance, window_uncast: *stuff.Window) void {
        //var this: *@This() = @alignCast(@ptrCast(instance.object));
        var window: *ZRenderGL33Window = @alignCast(@ptrCast(window_uncast));
        var lastFrameTime = std.time.microTimestamp();
        var currentFrameTime = lastFrameTime;
        while(!glfw.windowShouldClose(window.glfwWindow)) {
            // TODO: poll events once per frame
            // instead of once per window per frame
            glfw.pollEvents();
            currentFrameTime = std.time.microTimestamp();
            window.setup.onRender(instance, window_uncast, currentFrameTime - lastFrameTime);
            lastFrameTime = currentFrameTime;
            glfw.swapBuffers(window.glfwWindow);
        }
    }

    pub fn clearToColor(instance: Instance, window_uncast: *stuff.Window, color: stuff.Color) void {
        _ = window_uncast;
        _ = instance;
        gl.clearColor(@as(f32, @floatFromInt(color.r)) / 256.0, @as(f32,@floatFromInt(color.g)) / 256.0, @as(f32, @floatFromInt(color.b)) / 256.0, @as(f32, @floatFromInt(color.a)) / 256.0);
    }
};

const ZRenderGL33Window = struct {
    glfwWindow: *glfw.Window,
    setup: stuff.ZRenderSetup,
};