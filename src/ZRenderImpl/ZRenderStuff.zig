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
    // OOP LOL?
    vtable: *const ZRenderInstanceVTable,
    object: *anyopaque,
    
    //TODO: generate instance functions from vtable,
    // So adding functions is less work.
    // The ideal solution would be a function that takes the vtable type
    // and turns it into a struct.

    pub inline fn deinit(this: @This()) void {
        this.vtable.deinit(this);
    }
    
    pub inline fn initWindow(this: @This(), settings: WindowSettings, setup: ZRenderSetup) ?*Window {
        return this.vtable.initWindow(this, settings, setup);
    }

    pub inline fn deinitWindow(this: @This(), window: *Window) void {
        this.vtable.deinitWindow(this, window);
    }

    pub inline fn runWindow(this: @This(), window: *Window) void {
        this.vtable.runWindow(this, window);    
    }

    pub inline fn clearToColor(this: @This(), window: *Window, color: Color) void {
        this.vtable.clearToColor(this, window, color);
    }
};

pub const ZRenderInstanceVTable = struct {
    deinit: *const fn(instance: Instance) void,
    initWindow: *const fn(instance: Instance, settings: WindowSettings, setup: ZRenderSetup) ?*Window,
    deinitWindow: *const fn(instance: Instance, window: *Window) void,
    runWindow: *const fn(instance: Instance, window: *Window) void,
    clearToColor: *const fn (instance: Instance, window: *Window, color: Color) void,

};

/// a setup is a set of all the callbacks & runtime information of a window.
/// A user creates a setup, then uses that setup as an argument to creating a window.
pub const ZRenderSetup = struct {
    /// function callback for each frame.
    /// Delta is in micro seconds
    onRender: *const fn(instance: Instance, window: *Window, delta: i64) void,
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

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// a pre-made setup for the hello world example
// TODO: setup custom data
var time: i64 = 0;
fn debugSetupOnRender(instance: Instance, window: *Window, delta: i64) void {
    time += delta;
    instance.clearToColor(window, .{.r = 1, .g = 0, .b = 1, .a = 1});
}
pub const debug_setup = ZRenderSetup {
    .onRender = &debugSetupOnRender,
};