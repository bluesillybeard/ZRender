const std = @import("std");
const instance = @import("ZRender/instance.zig");
const MockInstance = @import("ZRender/MockInstance.zig").MockInstance;
const GL46Instance = @import("ZRender/GL46Instance.zig").GL46Instance;
// ZRender public API

// forward declarations
pub const Instance = instance.Instance;
pub const Color = instance.Color;
pub const Matrix3 = instance.Matrix3;
pub const Transform2D = instance.Transform2D;
pub const WindowSettings = instance.WindowSettings;
pub const WindowHandle = instance.WindowHandle;
pub const CreateWindowError = instance.CreateWindowError;
pub const Shader = instance.Shader;
pub const MeshHandle = instance.MeshHandle;
pub const DrawObject = instance.DrawObject;
pub const Event = instance.Event;
pub const WindowEvent = instance.WindowEvent;
pub const EventError = instance.EventError;
pub const FrameArguments = instance.FrameArguments;

pub const InstanceArgs = struct {
    enableMock: bool = false,
    enableGL46: bool = true,
    allocator: std.mem.Allocator,
};

pub fn initInstance(args: InstanceArgs) !instance.Instance {
    // If mock is enabled, completely ignore all other backends and just use it.
    if(args.enableMock) {
        const instanceObj = try args.allocator.create(MockInstance);
        instanceObj.* = MockInstance.init(args.allocator);
        return instance.Instance.initFromImplementer(MockInstance, instanceObj);
    }
    // TODO: backend chaining
    if(args.enableGL46) {
        const instanceObj = try GL46Instance.init(args.allocator);
        return instance.Instance.initFromImplementer(GL46Instance, instanceObj);
    }
    
    @panic("No supported backends found!");
}
