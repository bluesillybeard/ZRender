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
        try std.io.getStdOut().writer().print("init -> {}\n", .{this});
        return this;
    }

    pub fn deinitInstance(this: *MockInstance) void {
        std.io.getStdOut().writer().print("deinitInstance\n", .{}) catch unreachable;
        this.allocator.destroy(this);
    }

    pub fn createWindow(this: *MockInstance, options: zrender.WindowSettings) instance.errors.CreateWindowError!zrender.WindowHandle {
        const handle = this.rng.random().int(usize);
        std.io.getStdOut().writer().print("createWindow {} -> {}\n", .{options, handle}) catch unreachable;
        return handle;
    }

    pub fn deinitWindow(this: *MockInstance, window: zrender.WindowHandle) void {
        _ = this;
        std.io.getStdOut().writer().print("deinitWindow {}\n", .{window}) catch unreachable;
    }

    pub fn enumerateEvent(this: *MockInstance) instance.errors.EnumerateEventError!?zrender.Event {
        _ = this;
    
        // TODO: all the events
        std.io.getStdOut().writer().print("enumerateEvent -> {any}\n", .{null}) catch unreachable;
        return null;
    }

    pub fn createDrawObject(this: *MockInstance, data: zrender.DrawData) instance.errors.CreateDrawObjectError!zrender.DrawObjectHandle {
        const handle = this.rng.random().int(usize);
        std.io.getStdOut().writer().print("createDrawObject {} -> {}\n", .{data, handle}) catch unreachable;
        return handle;
    }

    pub fn deinitDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle) void {
        _ = this;
        std.io.getStdOut().writer().print("deinitDrawObject {}\n", .{draw}) catch unreachable;
    }

    pub fn replaceDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle, data: zrender.DrawData) void {
        _ = this;
        std.io.getStdOut().writer().print("replaceDrawObject {} {}\n", .{draw, data}) catch unreachable;
    }

    pub fn modifyDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle, data: zrender.DrawDiff) void {
        _ = this;
        std.io.getStdOut().writer().print("modifyDrawObject {} {}\n", .{draw, data}) catch unreachable;
    }
    
    pub fn fakeUseDrawObject(this: *MockInstance, draw: zrender.DrawObjectHandle) void {
        _ = this;
        std.io.getStdOut().writer().print("fakeUseDrawObject {}\n", .{draw}) catch unreachable;
    }

    pub fn beginFrame(this: *MockInstance, args: zrender.BeginFrameArgs) void {
        _ = this;
        std.io.getStdOut().writer().print("beginFrame {}\n", .{args}) catch unreachable;
    }

    /// It is undefined to submit a draw object with a different shader type to the given data.
    pub fn submitDrawList(this: *MockInstance, window: zrender.WindowHandle, draws: []const zrender.DrawObject) void {
        _ = this;
        std.io.getStdOut().writer().print("submitDrawList {} {any}\n", .{window, draws}) catch unreachable;
    }

    pub fn finishFrame(this: *MockInstance, args: zrender.FinishFrameArgs) void {
        _ = this;
        std.io.getStdOut().writer().print("finishFrame {}\n", .{args}) catch unreachable;
        // In order to give half-decently realistic timing, wait a bit before continuing
        std.time.sleep(std.time.ns_per_s / 90);
    }
};