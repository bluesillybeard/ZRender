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

const Mesh = struct {
    vertexBuffer: gl.GLuint,
    indexBuffer: gl.GLuint,
    numIndices: usize,
    usageHint: Instance.MeshUsageHint,
};

const numShaderEnums: usize = blk: {
    var n = 0;
    for(@typeInfo(@typeInfo(Instance.Shader).Union.tag_type.?).Enum.fields) |field| {
        if(field.value > n) {
            n = field.value;
        }
    }
    break :blk n+1;
};

const Shader = struct {
    program: gl.GLuint,
    vertexArrayObject: gl.GLuint,
};

pub const GL41Instance = struct {
    allocator: std.mem.Allocator,
    context: ?sdl.gl.Context,
    // This is a sparse list of windows, so the window handle is the same as an index into this list.
    windows: std.ArrayList(?Window),
    // The index into this array is the tag index from the shader of a draw object
    shaderPrograms: [numShaderEnums] ?Shader,
    pub fn init(allocator: std.mem.Allocator) !*GL41Instance {
        const self = try allocator.create(GL41Instance);
        self.* = .{
            .allocator = allocator,
            .context = null,
            .windows = std.ArrayList(?Window).init(allocator),
            .shaderPrograms = [_]?Shader{null} ** numShaderEnums,
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
            sdl.gl.setAttribute(.{.context_major_version = 4}) catch return Instance.CreateWindowError.createWindowError;
            sdl.gl.setAttribute(.{.context_minor_version = 1}) catch return Instance.CreateWindowError.createWindowError;
            sdl.gl.setAttribute(.{.context_profile_mask = .core}) catch return Instance.CreateWindowError.createWindowError;
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
    
        if(this.windows.items[window]) |*windowObj| {
            sdl.gl.makeCurrent(this.context.?, windowObj.sdlWindow) catch @panic("Failed to make window current");
            gl.clear(gl.COLOR_BUFFER_BIT);
            for(windowObj.draws.items) |d| {
                this.drawDrawObject(d);
                d.deinit(this.allocator);
            }
            windowObj.draws.clearRetainingCapacity();
            sdl.gl.setSwapInterval(if(args.vsync) .adaptive_vsync else .immediate) catch unreachable;
            sdl.gl.swapWindow(windowObj.sdlWindow);
        }
    }

    pub fn createMeshf32(this: *GL41Instance, vertices: []const f32, indices: []const u32, hint: Instance.MeshUsageHint) Instance.CreateMeshError!Instance.MeshHandle {
        const usage: gl.GLenum = switch (hint) {
            .cold => gl.STATIC_DRAW,
            .draw => gl.STATIC_DRAW,
            .draw_write => gl.DYNAMIC_DRAW,
        };

        var buffers: [2]gl.GLuint = undefined; 
        gl.genBuffers(2, &buffers);
        const vertexBuffer = buffers[0];
        const indexBuffer = buffers[1];
        gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(vertices.len * @sizeOf(f32)), vertices.ptr, usage);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr, usage);

        // TODO: store meshes in contiguous memory instead of allocating them like this
        const mesh = this.allocator.create(Mesh) catch return Instance.CreateMeshError.createMeshError;
        mesh.* = Mesh{
            .indexBuffer = indexBuffer,
            .vertexBuffer = vertexBuffer,
            .numIndices = indices.len,
            .usageHint = hint,
        };
        return @intFromPtr(mesh);
    }

    pub fn submitDrawObject(this: *GL41Instance, window: Instance.WindowHandle, object: Instance.DrawObject) void {
        if(this.windows.items[window]) |*windowObj| {
            windowObj.draws.append(object.duplicate(this.allocator) catch unreachable ) catch unreachable;
        }
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

    fn drawDrawObject(this: *GL41Instance, object: Instance.DrawObject) void {
        this.loadAndBindShader(object.shader);
        for(object.draws) |meshUncast| {
            const mesh: *Mesh = @ptrFromInt(meshUncast);
            gl.bindBuffer(gl.ARRAY_BUFFER, mesh.vertexBuffer);
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.indexBuffer);
            gl.drawElements(gl.TRIANGLES, @intCast(mesh.numIndices), gl.UNSIGNED_INT, null);
        }
    }

    fn loadAndBindShader(this: *GL41Instance, shader: Instance.Shader) void {
        switch (shader) {
            .SolidColor => |solidColor| {

                // TODO: look at the assembly for this part and make sure it's inlining it to always be SolidColor (aka zero)
                //  Do that once there are multile possible shaders
                const shaderIndex = @intFromEnum(shader);

                var shaderObj = this.shaderPrograms[shaderIndex];
                // If the shader isn't compiled, then compile it
                if(shaderObj == null) {
                    const vertexGLSL = @embedFile("GL41/shaders/SolidColor.vertex.glsl");
                    const fragmentGLSL = @embedFile("GL41/shaders/SolidColor.fragment.glsl");
                    const program = compileShader(vertexGLSL, fragmentGLSL);

                    var vertexArrayObject: gl.GLuint = undefined;
                    gl.genVertexArrays(1, &vertexArrayObject);
                    gl.bindVertexArray(vertexArrayObject);
                    gl.vertexAttribPointer(0, 2, gl.FLOAT, 0, 0, null);

                    shaderObj = Shader{
                        .program = program,
                        .vertexArrayObject = vertexArrayObject,
                    };
                    this.shaderPrograms[shaderIndex] = shaderObj;
                }

                //shaderObj is guaranteed to not be null at this point.
                const program = shaderObj.?.program;
                gl.useProgram(program);
                gl.programUniform4f(program, 0, solidColor.color.r, solidColor.color.g, solidColor.color.b, solidColor.color.a);
                // In this engine, matrices are stored in row-major order.
                // OpenGL is freakishly weird and does it the other way around, with column major order.
                // Thankfully, OpenGL takes a boolean when recieving matrix uniforms that will automatically convert it.
                gl.programUniformMatrix3fv(program, 1, 1, 1, @ptrCast(&solidColor.transform.matrix));
            }
        }
    }

    /// Loads and compiles a shader program.
    inline fn compileShader(vertexGLSL: []const u8, fragmentGLSL: []const u8) gl.GLuint {
        const vertexShader = gl.createShader(gl.VERTEX_SHADER);
        defer gl.deleteShader(vertexShader);
        const vertexLen: gl.GLint = @intCast(vertexGLSL.len);
        gl.shaderSource(vertexShader, 1, &vertexGLSL.ptr, &vertexLen);
        gl.compileShader(vertexShader);

        var success: gl.GLint = undefined;
        gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
        if(success  == 0){
            var buffer = [_]u8{0} ** 512;
            gl.getShaderInfoLog(vertexShader, 512, null, &buffer);
            std.debug.print("{s}", .{&buffer});
        }

        const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
        defer gl.deleteShader(fragmentShader);
        const fragmentLen: gl.GLint = @intCast(fragmentGLSL.len);
        gl.shaderSource(fragmentShader, 1, &fragmentGLSL.ptr, &fragmentLen);
        gl.compileShader(fragmentShader);

        gl.getShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
        if(success  == 0){
            var buffer = [_]u8{0} ** 512;
            gl.getShaderInfoLog(fragmentShader, 512, null, &buffer);
            std.debug.print("{s}", .{&buffer});
        }

        const program = gl.createProgram();
        gl.attachShader(program, vertexShader);
        defer gl.detachShader(program, vertexShader);
        gl.attachShader(program, fragmentShader);
        defer gl.detachShader(program, fragmentShader);
        gl.linkProgram(program);

        gl.getProgramiv(program, gl.LINK_STATUS, &success);
        if(success  == 0){
            var buffer = [_]u8{0} ** 512;
            gl.getProgramInfoLog(program, 512, null, &buffer);
            std.debug.print("{s}", .{&buffer});
        }
        return program;
    }

    inline fn notImplemented() noreturn {
        @panic("Not implemented on the OpenGL 4.1 backend");
    }

    fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
        _ = ctx;
        return sdl.gl.getProcAddress(name);
    }
};
