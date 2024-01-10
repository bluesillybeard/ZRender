const std = @import("std");
const instance = @import("instance.zig");
const zrender = @import("zrender.zig");
// A mock instance that just prints called functions and returns plausible values

pub const MockInstance = struct {
    rng: std.rand.DefaultPrng,
    allocator: std.mem.Allocator,
    pub fn init(options: instance.InstanceOptions) !*MockInstance {
        const this = try options.allocator.create(MockInstance);
        this.rng = std.rand.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
        this.allocator = options.allocator;
        std.debug.print("init -> {}\n", .{this});
        return this;
    }

    pub fn deinitInstance(this: *MockInstance) void {
        std.debug.print("deinitInstance\n", .{});
        this.allocator.destroy(this);
    }

    pub fn createWindow(this: *MockInstance, options: zrender.WindowSettings) instance.errors.CreateWindowError!zrender.WindowHandle {
        const handle = this.rng.random().int(usize);
        std.debug.print("createWindow {} -> {}\n", .{options, handle});
        return handle;
    }

    pub fn deinitWindow(this: *MockInstance, window: zrender.WindowHandle) void {
        _ = this;
        std.debug.print("deinitWindow {}\n", .{window});
    }

    pub fn enumerateEvent(this: *MockInstance) instance.errors.EnumerateEventError!?zrender.Event {
        _ = this;
    
        // TODO: all the events
        std.debug.print("enumerateEvent -> {any}\n", .{null});
        return null;
    }

    pub fn createDrawObject(this: *MockInstance, data: zrender.DrawData) instance.errors.CreateDrawObjectError!zrender.DrawObjectHandle {
        const handle = this.rng.random().int(usize);
        std.debug.print("createDrawObject {} -> {}\n", .{data, handle});
        return handle;
    }

    pub fn deinitDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle) void {
        _ = this;
        std.debug.print("dinitDrawObject {}\n", .{draw});
    }

    pub fn replaceDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle, data: zrender.DrawData) void {
        _ = this;
        std.debug.print("replaceDrawObject {} {}\n", .{draw, data});
    }

    pub fn modifyDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle, data: zrender.DrawDiff) void {
        _ = this;
        std.debug.print("modifyDrawObject {} {}\n", .{draw, data});
    }
    
    pub fn fakeUseDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle) void {
        _ = this;
        std.debug.print("fakeUseDrawObject {}\n", .{draw});
    }

    pub fn beginFrame(this: *MockInstance, args: zrender.BeginFrameArgs) void {
        _ = this;
        std.debug.print("beginFrame {}\n", .{args});
    }

    /// It is undefined to submit a draw object with a different shader type to the given data.
    pub fn submitDrawList(this: *MockInstance, window: zrender.WindowHandle, draws: []const zrender.DrawObject) void {
        _ = this;
        std.debug.print("submitDrawList {} {any}\n", .{window, draws});
    }

    pub fn finishFrame(this: *MockInstance, args: zrender.FinishFrameArgs) void {
        _ = this;
        std.debug.print("finishFrame {}\n", .{args});
    }
};