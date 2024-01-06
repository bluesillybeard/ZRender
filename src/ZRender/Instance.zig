const interface = @import("interface");
const std = @import("std");

// A bunch of small types

pub const Color = struct {
    r: f32, g: f32, b: f32, a: f32,
};

// It is extern so that implementations can just yeet the data into the backend directly
// instead of having to convert them into a C compatible form.
pub const Matrix3 = extern struct {
    // X      Y         Z
    m00: f32, m01: f32, m02: f32, //X
    m10: f32, m11: f32, m12: f32, //Y
    m20: f32, m21: f32, m22: f32, //Z

    pub const Identity = Matrix3 {
        .m00 = 1, .m01 = 0, .m02 = 0,
        .m10 = 0, .m11 = 1, .m12 = 0,
        .m20 = 0, .m21 = 0, .m22 = 1,
    };
    // TODO: mathmatical functions and stuff
};

pub const Transform2D = struct {
    matrix: Matrix3,

    // TODO: transformation functions

    /// Identity transformation - no change from input
    pub const Identity = Transform2D{
        .matrix = Matrix3.Identity,
    };
};

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
    SolidColor: struct{color: Color, transform: Transform2D},
};

// A handle to an actual mesh on the GPU
pub const MeshHandle = usize;

pub const MeshUsageHint = enum {
    /// The mesh is basically never used
    cold,
    /// The mesh is drawn
    draw,
    /// the mesh is drawn and written to.
    draw_write,
};

pub const DrawObject = struct {
    draws: []const MeshHandle,
    shader: Shader,

    pub fn duplicate(this: DrawObject, allocator: std.mem.Allocator) !DrawObject {
        return DrawObject{
            .draws  = try allocator.dupe(MeshHandle, this.draws),
            .shader = this.shader,
        };
    }

    pub fn deinit(this: DrawObject, allocator: std.mem.Allocator) void {
        allocator.free(this.draws);
    }
};
pub const Event = struct {
    window: WindowHandle,
    event: WindowEvent,
};

// various errors
pub const WindowEvent = union(enum) {
    exit,
};

pub const EventError = error {
    // TODO: more specific error
    eventError,
};

pub const CreateMeshError = error {
    createMeshError,
};

pub const FrameArguments = struct {
    vsync: bool = true,
};

pub fn MakeInstance(comptime This: type) type {
    return struct {
        /// Creates a window, and either returns an error or a handle to the newly created window
        pub inline fn createWindow(this: This, s: WindowSettings) CreateWindowError!WindowHandle {
            return this.vtable.createWindow(this.object, s);
        }

        /// Destroys an instance.
        pub inline fn deinit(this: This) void {
            this.vtable.deinit(this.object);
        }

        /// Closes and destroys a window.
        pub inline fn deinitWindow(this: This, window: WindowHandle) void {
            this.vtable.deinitWindow(this.object, window);
        }

        /// Polls events from all windows
        /// To be more specific, it does a number of things:
        /// - prepare each window to polling events
        /// - poll events for every window and store them into a buffer
        /// - handle certain events directly, such as framebuffer resizing
        /// - prepare for events to be enumerated
        pub inline fn pollEvents(this: This) void {
            this.vtable.pollEvents(this.object);
        }

        /// Use in a while loop to enumerate events.
        /// If there are no events left, returns null.
        /// Will return an error if pollEvents was never called, or if an invalid event is recieved.
        pub inline fn enumerateEvent(this: This) EventError!?Event {
            return this.vtable.enumerateEvent(this.object);
        }

        // TODO: verify this is the best order of events for this
        /// Runs a single frame on the window.
        /// To be more specific, it does a number of things:
        /// - run each submitted draw list
        /// - swap the framebuffer
        /// - resize the framebuffer if it needs to be
        pub inline fn runFrame(this: This, window: WindowHandle, args: FrameArguments) void {
            this.vtable.runFrame(this.object, window, args);
        }
        // TODO: more mesh creation functions for various types of meshes

        /// Creates a mesh from a vertex array of floats and indices.
        pub inline fn createMeshf32(this: This, vertices: []const f32, indices: []const u32, hint: MeshUsageHint) CreateMeshError!MeshHandle {
            return this.vtable.createMeshf32(this.object, vertices, indices, hint);
        }

        /// submits a single draw object to a window
        pub inline fn submitDrawObject(this: This, window: WindowHandle, object: DrawObject) void {
            this.vtable.submitDrawObject(this.object, window, object);
        }
    };
}

/// Instance contains that majority of the public API (well the part of the API that interacts with actual stuff)
pub const Instance = interface.MakeInterface(MakeInstance, .{});
