const std = @import("std");
const Instance = @import("ZRender/Instance.zig");
const MockInstance = @import("ZRender/MockInstance.zig").MockInstance;
const GL46Instance = @import("ZRender/GL46Instance.zig").GL46Instance;
// ZRender public API

// forward declarations
pub const Color = Instance.Color;
pub const Matrix3 = Instance.Matrix3;
pub const Transform2D = Instance.Transform2D;
pub const WindowSettings = Instance.WindowSettings;
pub const WindowHandle = Instance.WindowHandle;
pub const CreateWindowError = Instance.CreateWindowError;
pub const Shader = Instance.Shader;
pub const MeshHandle = Instance.MeshHandle;
pub const DrawObject = Instance.DrawObject;
pub const Event = Instance.Event;
pub const WindowEvent = Instance.WindowEvent;
pub const EventError = Instance.EventError;
pub const FrameArguments = Instance.FrameArguments;

pub const InstanceArgs = struct {
    enableMock: bool = false,
    enableGL46: bool = true,
    allocator: std.mem.Allocator,
};

pub fn initInstance(args: InstanceArgs) !Instance.Instance {
    // If mock is enabled, completely ignore all other backends and just use it.
    if(args.enableMock) {
        const instance = try args.allocator.create(MockInstance);
        instance.* = MockInstance.init(args.allocator);
        return Instance.Instance.initFromImplementer(MockInstance, instance);
    }
    // TODO: backend chaining
    if(args.enableGL46) {
        const instance = try GL46Instance.init(args.allocator);
        return Instance.Instance.initFromImplementer(GL46Instance, instance);
    }
    
    @panic("No supported backends found!");
}
