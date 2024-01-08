const std = @import("std");
const sdl = @import("sdl");
const gl = @import("GL46/GL46Bind.zig");
const instance = @import("instance.zig");
// Implementation of Instance for OpenGL 4.6 and SDL2

pub const GL46Instance = struct {
    allocator: std.mem.Allocator,
    context: ?sdl.gl.Context,
    // This is a sparse list of windows, so the window handle is the same as an index into this list.
    windows: std.ArrayList(?Window),
    // The index into this array is the tag index from the shader of a draw object
    shaderPrograms: [numShaderEnums] ?Shader,

    //"Wait, there's only one VAO?"
    // Yes, there's only one VAO. Why? Because in ZRender meshes are ONLY the raw data, they don't have a VAO - the information a VAO would use goes in a shader
    //"So, why isn't it stored in the shader?"
    // because, a VAO's data is inherently tied to a mesh - So, I would have to completely redefine the VAO every draw call anyway.
    // So, instead of redundantly storing a VAO for every shader, a single VAO is used.
    vertexArrayObject: gl.GLuint,
    // YOu wouldn't believe how long it took me to fugure out why it kept using the wrong vertex buffer.
    // Eventually I found out it's because a different one was bound to the shaders VAO,
    // and the only way to bind a different one is to reset the VAO completely.

    pub fn init(allocator: std.mem.Allocator) !*GL46Instance {
        const self = try allocator.create(GL46Instance);
        self.* = .{
            .allocator = allocator,
            .context = null,
            .windows = std.ArrayList(?Window).init(allocator),
            .shaderPrograms = [_]?Shader{null} ** numShaderEnums,
            .vertexArrayObject = undefined,
        };
        return self;
    }

    pub fn createWindow(this: *GL46Instance, s: instance.WindowSettings) instance.CreateWindowError!instance.WindowHandle {
        // find an empty spot in the list of windows
        var id: usize = undefined;
        // If the list of windows has no items, make a spot
        if (this.windows.items.len == 0) {
            this.windows.append(null) catch return instance.CreateWindowError.createWindowError;
        }
        for (this.windows.items, 0..) |w, i| {
            if (w == null) {
                id = i;
                break;
            }
            // If we're at the last item and still haven't found a spot, make one
            if (i == this.windows.items.len - 1) {
                this.windows.append(null) catch return instance.CreateWindowError.createWindowError;
                id = i + 1;
                break;
            }
        }
        // create the window
        const window = Window.init(s, this.allocator) catch return instance.CreateWindowError.createWindowError;
        // place the window into the list
        this.windows.items[id] = window;

        // Because OpenGL is stupid and annoying, it HAS to be attached to a window,
        // which is why it is initialized after the window, not before.
        if(this.context == null) {
            sdl.gl.setAttribute(.{.context_major_version = 4}) catch return instance.CreateWindowError.createWindowError;
            sdl.gl.setAttribute(.{.context_minor_version = 6}) catch return instance.CreateWindowError.createWindowError;
            sdl.gl.setAttribute(.{.context_profile_mask = .core}) catch return instance.CreateWindowError.createWindowError;
            this.context = sdl.gl.createContext(window.sdlWindow) catch return instance.CreateWindowError.createWindowError;
            gl.load(void{}, loadProc) catch return instance.CreateWindowError.createWindowError;
            // create the singular VAO for the entire instance
            gl.genVertexArrays(1, &this.vertexArrayObject);
        }
        return id;
    }

    pub fn deinit(this: *GL46Instance) void {
        this.windows.deinit();
        sdl.quit();
        this.allocator.destroy(this);
    }

    pub fn deinitWindow(this: *GL46Instance, window: instance.WindowHandle) void {
        // get the actual window object
        const windowObj = this.windows.items[window];
        // remove the window from the list
        this.windows.items[window] = null;
        // actually destroy the window
        if(windowObj) |w| {
            w.deinit();
        }
    }

    pub fn pollEvents(this: *GL46Instance) void {
        _ = this;

        // with SDL, polling the events ahead of time is more or less useless.
        // The function exists in case of a future supported platform where polling the events ahead of time is useful.
    }

    pub fn enumerateEvent(this: *GL46Instance) instance.EventError!?instance.Event {
        while (sdl.pollEvent()) |event| {
            // TODO: all the events
            switch (event) {
                .window => |windowEvent| {
                    const window = this.getWindowFromSdlId(windowEvent.window_id);
                    if(window == null){
                        // TODO: Figure out why SDL appears to give events for windows that don't exist
                        continue;
                    }
                    if (windowEvent.type == .close) {
                        return instance.Event{
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

    pub fn runFrame(this: *GL46Instance, window: instance.WindowHandle, args: instance.FrameArguments) void {
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

    pub fn createMeshf32(this: *GL46Instance, vertices: []const f32, indices: []const u32, hint: instance.MeshUsageHint) instance.CreateMeshError!instance.MeshHandle {
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
        const mesh = this.allocator.create(Mesh) catch return instance.CreateMeshError.createMeshError;
        mesh.* = Mesh{
            .indexBuffer = indexBuffer,
            .vertexBuffer = vertexBuffer,
            .numIndices = indices.len,
            .usageHint = hint,
        };
        return @intFromPtr(mesh);
    }

    pub fn deinitMesh(this: *GL46Instance, meshUncast: instance.MeshHandle) void {
        const mesh: *Mesh = @ptrFromInt(meshUncast);
        gl.deleteBuffers(2, &[2]gl.GLuint{mesh.indexBuffer, mesh.vertexBuffer});
        this.allocator.destroy(mesh);
    }

    pub fn submitDrawObject(this: *GL46Instance, window: instance.WindowHandle, object: instance.DrawObject) void {
        if(this.windows.items[window]) |*windowObj| {
            windowObj.draws.append(object.duplicate(this.allocator) catch unreachable ) catch unreachable;
        }
    }

    pub fn getWindowFromSdlId(this: *GL46Instance, wid: u32) ?instance.WindowHandle {
        for(this.windows.items, 0..) |windowOrNone, handle| {
            if(windowOrNone) |window| {
                // The SDL wrapper doesn't have this function yet. Luckily, we can directly call the C function.
                const window_id = sdl.c.SDL_GetWindowID(window.sdlWindow.ptr);
                if(window_id == wid) {
                    return handle;
                }
            }
        }
        return null;
    }

    fn drawDrawObject(this: *GL46Instance, object: instance.DrawObject) void {
        for(object.draws) |meshUncast| {
            const mesh: *Mesh = @ptrFromInt(meshUncast);
            this.bind(object.shader, mesh);
            gl.drawElements(gl.TRIANGLES, @intCast(mesh.numIndices), gl.UNSIGNED_INT, null);
        }
    }

    /// Binds a shader program, sets uniforms, and binds the mesh to the shader in preparation for draw calls.
    fn bind(this: *GL46Instance, shader: instance.Shader, mesh: *Mesh) void {
        const shaderObj  = this.getShader(shader);
        gl.useProgram(shaderObj.program);
        gl.bindVertexArray(this.vertexArrayObject);
        switch (shader) {
            .SolidColor => |solidColor| {
                gl.uniform4f(0, solidColor.color.r, solidColor.color.g, solidColor.color.b, solidColor.color.a);
                gl.uniformMatrix3fv(1, 1, 1, @ptrCast(&solidColor.transform.matrix));
                gl.bindBuffer(gl.ARRAY_BUFFER, mesh.vertexBuffer);
                gl.vertexAttribPointer(0, 2, gl.FLOAT, 0, 2 * @sizeOf(f32), null); //pos
                gl.enableVertexAttribArray(0);
            },
            .VertexColor => |vertexColor| {
                gl.uniformMatrix3fv(1, 1, 1, @ptrCast(&vertexColor.transform.matrix));
                gl.bindBuffer(gl.ARRAY_BUFFER, mesh.vertexBuffer);
                gl.vertexAttribPointer(0, 2, gl.FLOAT, 0, 6 * @sizeOf(f32), null); //pos
                gl.enableVertexAttribArray(0);
                gl.vertexAttribPointer(1, 4, gl.FLOAT, 0, 6 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32))); //color
                gl.enableVertexAttribArray(1);
            }
        }
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.indexBuffer);
    }

    /// Loads and compiles a shader if it hasn't been already
    fn getShader(this: *GL46Instance, shader: instance.Shader) Shader {
        const shaderIndex = @intFromEnum(shader);
        const shaderObj = this.shaderPrograms[shaderIndex];
        // If the shader is already compiled, reutrn it 
        if(shaderObj) |s| {
            return s;
        }
        // compile the shader
        var program: gl.GLuint = undefined;
        switch (shader) {
            .SolidColor => {
                // Because embedFile happens at compile time, I can't easily merge them out of this switch.
                const vertexGLSL = @embedFile("GL46/shaders/SolidColor.vertex.glsl");
                const fragmentGLSL = @embedFile("GL46/shaders/SolidColor.fragment.glsl");
                program = compileShader(vertexGLSL, fragmentGLSL);
            },
            .VertexColor => {            
                const vertexGLSL = @embedFile("GL46/shaders/VertexColor.vertex.glsl");
                const fragmentGLSL = @embedFile("GL46/shaders/VertexColor.fragment.glsl");
                program = compileShader(vertexGLSL, fragmentGLSL);
            }
        }
        const s = Shader{
            .program = program,
        };
        this.shaderPrograms[shaderIndex] = s;
        return s;
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
        @panic("Not implemented on the OpenGL 4.6 backend");
    }

    fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
        _ = ctx;
        return sdl.gl.getProcAddress(name);
    }
};

const Window = struct {
    sdlWindow: sdl.Window,
    // draws is entirely owned by the Window.
    // They are copies of the ones given from the submitDraw method
    draws: std.ArrayList(instance.DrawObject),

    pub fn init(settings: instance.WindowSettings, allocator: std.mem.Allocator) !Window {
        return Window{
            // TODO: position
            .sdlWindow = try sdl.createWindow(settings.name, .default, .default, @intCast(settings.width), @intCast(settings.height), .{
                .resizable = settings.resizable,
                .context = .opengl,
            }),
            .draws = std.ArrayList(instance.DrawObject).init(allocator),
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
    usageHint: instance.MeshUsageHint,
};

const numShaderEnums: usize = blk: {
    var n = 0;
    for(@typeInfo(@typeInfo(instance.Shader).Union.tag_type.?).Enum.fields) |field| {
        if(field.value > n) {
            n = field.value;
        }
    }
    break :blk n+1;
};

const Shader = struct {
    program: gl.GLuint,
};

