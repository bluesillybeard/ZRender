const std = @import("std");
const Instance = @import("instance.zig");

/// A fake implementation of an instance for debug purposes.
/// It prints the called functions, and returns a plausible result for each function.
pub const MockInstance = struct {
    allocator: std.mem.Allocator,
    rng: std.rand.DefaultPrng,
    lastWindow: usize,
    pub fn init(allocator: std.mem.Allocator) MockInstance {
        const this = MockInstance {
            .allocator = allocator,
            .rng = std.rand.DefaultPrng.init(69420100),
            .lastWindow = 0,
        };
        return this;
    }
    pub fn createWindow(this: *MockInstance, s: Instance.WindowSettings) Instance.CreateWindowError!Instance.WindowHandle {
        // create a random number to serve as the ID
        const n: usize = @intCast(this.rng.next());
        std.debug.print("createWindow {} -> {}\n", .{s, n});
        this.lastWindow = @intCast(n);
        return n;
    }

    pub fn deinit(this: *MockInstance) void {
        std.debug.print("deinit\n", .{});
        this.allocator.destroy(this);
    }

    pub fn deinitWindow(this: *MockInstance, window: Instance.WindowHandle) void {
        _ = this;
        std.debug.print("deinitWindow {}\n", .{window});
    }

    pub fn pollEvents(this: *MockInstance) void {
        _ = this;
        std.debug.print("pollEvents\n", .{});
    
    }

    pub fn enumerateEvent(this: *MockInstance) Instance.EventError!?Instance.Event {
        var event: ?Instance.Event = null;
        // 1% chance of sending an exit event with the last window
        if(this.rng.random().float(f32) < 0.01) {
            event = .{
                .window = this.lastWindow,
                .event = .exit,
            };
        }
        std.debug.print("enumerateEvent -> {any}\n", .{event});
        return event;
    }

    pub fn runFrame(this: *MockInstance, window: Instance.WindowHandle, args: Instance.FrameArguments) void {
        _ = this;
        std.debug.print("runFrame {} {}\n", .{window, args});
    }

    pub fn _createMesh(this: *MockInstance, vertices: []const u8, indices: []const u32, hint: Instance.MeshUsageHint) Instance.CreateMeshError!Instance.MeshHandle {
        // TODO: for methods that recieve a mesh, make sure that mesh is one that is still valid.
        // create a random number to serve as the ID
        const n: usize = @intCast(this.rng.next());
        std.debug.print("_createMesh {any} {any} {} -> {}\n", .{vertices, indices, hint, n});
        return n;
    }

    pub fn deinitMesh(this: *MockInstance, meshUncast: Instance.MeshHandle) void {
        _ = this;
        std.debug.print("deinitMesh {}\n", .{meshUncast});
    }


    pub fn submitDrawObject(this: *MockInstance, window: Instance.WindowHandle, object: Instance.DrawObject) void {
        _ = this;
        std.debug.print("submitDrawObject {} {}\n", .{window, object});
    }
};