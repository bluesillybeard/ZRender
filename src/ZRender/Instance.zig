const interface = @import("interface");

// A bunch of small types

// Window related types
pub const WindowSettings = struct {
    width: u32 = 800,
    height: u32 = 600,
    name: [:0]const u8 = "ZRender window",
    yPos: ?u32 = null,
    xPos: ?u32 = null,
    resizable: bool = false,
};

pub const WindowHandle = usize;

// TODO: more specific errors
pub const CreateWindowError = error {
    createWindowError
};

// shader type
pub const Shader = union(enum) {
    /// Draws a mesh with a single solid color.
    /// Mesh Attributes: position (x: f32, y: f32)
    /// Other data: rgba color, floats where 0 -> black and 1 -> white
    SolidColor: struct{r: f32, g: f32, b: f32, a: f32},
};

// A handle to an actual mesh on the GPU
pub const MeshHandle = usize;

pub const Event = struct {
    window: WindowHandle,
    event: WindowEvent,
};

pub const WindowEvent = union(enum) {
    exit,
};

pub const EventError = error {
    // TODO: more specific error
    eventError,
};

pub const FrameArguments = struct {
    vsync: bool = true,
};

pub fn MakeInstance(comptime This: type) type {
    return struct {
        pub inline fn createWindow(this: This, s: WindowSettings) CreateWindowError!WindowHandle {
            return this.vtable.createWindow(this.object, s);
        }

        pub inline fn deinit(this: This) void {
            this.vtable.deinit(this.object);
        }

        pub inline fn deinitWindow(this: This, window: WindowHandle) void {
            this.vtable.deinitWindow(this.object, window);
        }

        pub inline fn pollEvents(this: This) void {
            this.vtable.pollEvents(this.object);
        }

        pub inline fn enumerateEvent(this: This) EventError!?Event {
            return this.vtable.enumerateEvent(this.object);
        }

        pub inline fn runFrame(this: This, window: WindowHandle, args: FrameArguments) void {
            this.vtable.runFrame(this.object, window, args);
        }
    };
}

/// Instance contains that majority of the public API (well the part of the API that interacts with actual stuff)
pub const Instance = interface.MakeInterface(MakeInstance, .{});
