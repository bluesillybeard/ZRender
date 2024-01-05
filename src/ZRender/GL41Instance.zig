const std = @import("std");
const sdl = @import("sdl");
const gl = @import("GL41/GL41Bind.zig");
const Instance = @import("Instance.zig");
// Implementation of Instance for OpenGL 4.1 and SDL2

const Window = struct {
    sdlWindow: sdl.Window,
    // draws is entirely owned by the Window.
    // They are copies of the ones given from the submitDraw method
    draws: std.ArrayList(Instance.DrawObject),

    pub fn init(settings: Instance.WindowSettings, allocator: std.mem.Allocator) !Window {
        return Window{
            // TODO: position
            .sdlWindow = try sdl.createWindow(settings.name, .default, .default, @intCast(settings.width), @intCast(settings.height), .{
                .resizable = settings.resizable,
                .context = .opengl,
            }),
            .draws = std.ArrayList(Instance.DrawObject).init(allocator),
        };
    }

    pub fn deinit(this: Window) void {
        this.sdlWindow.destroy();
        this.draws.deinit();
    }
};

pub const GL41Instance = struct {
    allocator: std.mem.Allocator,
    context: ?sdl.gl.Context,
    // This is a sparse list of windows, so the window handle is the same as an index into this list.
    windows: std.ArrayList(?Window),
    pub fn init(allocator: std.mem.Allocator) !*GL41Instance {
        const self = try allocator.create(GL41Instance);
        self.* = .{
            .allocator = allocator,
            .context = null,
            .windows = std.ArrayList(?Window).init(allocator),
        };
        return self;
    }

    pub fn createWindow(this: *GL41Instance, s: Instance.WindowSettings) Instance.CreateWindowError!Instance.WindowHandle {
        // find an empty spot in the list of windows
        var id: usize = undefined;
        // If the list of windows has no items, make a spot
        if (this.windows.items.len == 0) {
            this.windows.append(null) catch return Instance.CreateWindowError.createWindowError;
        }
        for (this.windows.items, 0..) |w, i| {
            if (w == null) {
                id = i;
                break;
            }
            // If we're at the last item and still haven't found a spot, make one
            if (i == this.windows.items.len - 1) {
                this.windows.append(null) catch return Instance.CreateWindowError.createWindowError;
            }
        }
        // create the window
        const window = Window.init(s, this.allocator) catch return Instance.CreateWindowError.createWindowError;
        // place the window into the list
        this.windows.items[id] = window;

        // Because OpenGL is stupid and annoying, it HAS to be attached to a window,
        // which is why it is initialized after the window, not before.
        if(this.context == null) {
            this.context = sdl.gl.createContext(window.sdlWindow) catch return Instance.CreateWindowError.createWindowError;
            gl.load(void{}, loadProc) catch return Instance.CreateWindowError.createWindowError;
        }
        return id;
    }

    pub fn deinit(this: *GL41Instance) void {
        this.windows.deinit();
        sdl.quit();
        this.allocator.destroy(this);
    }

    pub fn deinitWindow(this: *GL41Instance, window: Instance.WindowHandle) void {
        // get the actual window object
        const windowObj = this.windows.items[window];
        // remove the window from the list
        this.windows.items[window] = null;
        // actually destroy the window
        if(windowObj) |w| {
            w.deinit();
        }
    }

    pub fn pollEvents(this: *GL41Instance) void {
        _ = this;

        // with SDL, polling the events ahead of time is more or less useless.
        // The function exists in case of a future supported platform where polling the events ahead of time is useful.
    }

    pub fn enumerateEvent(this: *GL41Instance) Instance.EventError!?Instance.Event {
        while (sdl.pollEvent()) |event| {
            // TODO: all the events
            switch (event) {
                .window => |windowEvent| {
                    const window = this.getWindowFromSdlId(windowEvent.window_id);
                    if(window == null) return Instance.EventError.eventError;
                    if (windowEvent.type == .close) {
                        return Instance.Event{
                            .window = window.?,
                            .event = .exit,
                        };
                    }
                },

                else => {},
            }
        }
        return null;
    }

    pub fn runFrame(this: *GL41Instance, window: Instance.WindowHandle, args: Instance.FrameArguments) void {
        _ = args;
    
        if(this.windows.items[window]) |windowObj| {
            sdl.gl.makeCurrent(this.context.?, windowObj.sdlWindow) catch @panic("Failed to make window current");
            gl.clear(gl.COLOR_BUFFER_BIT);
            // TODO: actually run the draw objects
            sdl.gl.swapWindow(windowObj.sdlWindow);
        }
    }

    pub fn createMeshf32(this: *GL41Instance, vertices: []const f32, indices: []const u32) Instance.MeshHandle {
        _ = this;
        _ = vertices;
        _ = indices;

        notImplemented();
    }

    pub fn submitDrawObject(this: *GL41Instance, window: Instance.WindowHandle, object: Instance.DrawObject) void {
        _ = this;
        _ = window;
        _ = object;

        notImplemented();
    }

    pub fn getWindowFromSdlId(this: *GL41Instance, wid: u32) ?Instance.WindowHandle {
        // get the window handle from the SDL window ID
        const sdlWindowOrNone = sdl.Window.fromID(wid);
        if (sdlWindowOrNone) |sdlWindow| {
            for (this.windows.items, 0..) |windowOrNone, windowId| {
                if (windowOrNone) |window| {
                    if (window.sdlWindow.ptr == sdlWindow.ptr) {
                        return windowId;
                    }
                }
            }
        }
        return null;
    }

    pub inline fn notImplemented() noreturn {
        @panic("Not implemented on the OpenGL 4.1 backend");
    }

    fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
        _ = ctx;
        return sdl.gl.getProcAddress(name);
    }
};
