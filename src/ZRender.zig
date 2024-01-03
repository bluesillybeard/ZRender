const std = @import("std");
const Instance = @import("ZRender/Instance.zig");
const MockInstance = @import("ZRender/MockInstance.zig");
// ZRender public API

pub const InstanceArgs = struct {
    // TODO: false by default
    enableMock: bool = true,
    allocator: std.mem.Allocator,
};

pub fn initInstance(args: InstanceArgs) !Instance.Instance {
    // If mock is enabled, completely ignore all other backends and just use it.
    if(args.enableMock) {
        const instance = try args.allocator.create(MockInstance.MockInstance);
        instance.* = MockInstance.MockInstance.init(args.allocator);
        return Instance.Instance.initFromImplementer(MockInstance.MockInstance, instance);
    }
    @panic("No supported backends found!");
}
