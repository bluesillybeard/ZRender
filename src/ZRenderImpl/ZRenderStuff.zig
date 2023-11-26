const std = @import("std");
// Stuff that is used by many files
// Anything you need *SHOULD* be in the ordinary ZRender file. ZRender.zig should be the only file you import.
// Public types / functions that are in this / other files are exposed through ZRender.zig.
pub const GraphicsAPI = enum {
    OpenGL_3_3,
    None,
};

/// Instance is a Rust-like dynamic reference,
/// where the vtable is part of a wide pointer instead of being in the object itself.
/// Every ZRender function (with a few exceptions) is called from the instance.
/// I recomend either passing the instance through functions or making it a singleton.
pub const Instance = struct {
    // Whoa. is this an object-oriented inferface in a non-oop language?
    // Yes. yes it is. Isn't zig cool?
    vtable: *const ZRenderInstanceVTable,
    object: *anyopaque,
    
    //TODO: generate instance functions from vtable,
    // So adding functions is less work.
    // The ideal solution would be a function that takes the vtable type
    // and turns it into this struct.

    pub inline fn deinit(this: @This()) void {
        this.vtable.deinit(this);
    }
    
    pub inline fn initWindow(this: @This(), settings: WindowSettings, setup: ZRenderSetup) ?*Window {
        return this.vtable.initWindow(this, settings, setup);
    }

    pub inline fn deinitWindow(this: @This(), window: *Window) void {
        this.vtable.deinitWindow(this, window);
    }

    pub inline fn run(this: @This()) void {
        this.vtable.run(this);    
    }

    pub inline fn clearToColor(this: @This(), queue: *RenderQueue, color: Color) void {
        this.vtable.clearToColor(this, queue, color);
    }
};

pub const ZRenderInstanceVTable = struct {
    deinit: *const fn(instance: Instance) void,
    initWindow: *const fn(instance: Instance, settings: WindowSettings, setup: ZRenderSetup) ?*Window,
    deinitWindow: *const fn(instance: Instance, window: *Window) void,
    run: *const fn(instance: Instance) void,
    clearToColor: *const fn (instance: Instance, renderQueue: *RenderQueue, color: Color) void,

};

/// a setup is a set of all the callbacks & runtime information of a window.
/// A user creates a setup, then uses that setup as an argument to creating a window.
pub const ZRenderSetup = struct {
    /// function callback for each frame.
    /// Delta is in micro seconds
    onRender: *const fn(instance: Instance, window: *Window, queue: *RenderQueue, delta: i64, time: i64) void,
};

pub const WindowSettings = struct {
    width: u32 = 800,
    height: u32 = 600,
    name: [:0]const u8 = "ZRender window",
    monitor: ?u32 = null,
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
}
pub const debug_setup = ZRenderSetup {
    .onRender = &debugSetupOnRender,
};