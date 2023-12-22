const std = @import("std");
const gl = @import("ext/GL41Bind.zig");
const sdl = @import("sdl");
const ZRenderOptions = @import("ZRenderOptions.zig");

fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
    _ = ctx;
    return sdl.gl.getProcAddress(name);
}
pub fn ZRenderGL41(comptime options: ZRenderOptions) type {
    return struct {
        const stuff = @import("ZRenderStuff.zig").Stuff(options);
        // some 'static includes' because yeah
        const Instance = stuff.Instance;
        const Window = stuff.Window;
        pub fn initInstance(allocator: std.mem.Allocator, customData: *options.CustomInstanceData) !Instance {
            
            try sdl.init(.{.video = true});
            const obj = ZRenderGL41Instance{
                .allocator = allocator,
                .windows = std.ArrayList(*ZRenderGL41Window).init(allocator),
                .newWindows = std.ArrayList(*ZRenderGL41Window).init(allocator),
                .windowsToDeinit = std.ArrayList(*ZRenderGL41Window).init(allocator),
                .context = null,
                .customData = customData,
            };
            const object = try allocator.create(ZRenderGL41Instance);
            object.* = obj;
            return Instance.initFromImplementer(ZRenderGL41Instance, object);
        }

        const ZRenderGL41Instance = struct {
            allocator: std.mem.Allocator,
            context: ?sdl.gl.Context,
            windows: std.ArrayList(*ZRenderGL41Window),
            // Windows that have been created but not added to the list of windows
            newWindows: std.ArrayList(*ZRenderGL41Window),
            // Windows that have been queued to be deleted.
            windowsToDeinit: std.ArrayList(*ZRenderGL41Window),

            customData: *options.CustomInstanceData,

            pub fn deinit(this: *ZRenderGL41Instance) void {
                this.windows.deinit();
                this.newWindows.deinit();
                this.windowsToDeinit.deinit();
                sdl.quit();
                this.allocator.destroy(this);
            }

            pub fn getCustomData(this: *ZRenderGL41Instance) *options.CustomInstanceData {
                return this.customData;
            }

            pub fn initWindow(this: *ZRenderGL41Instance, settings: stuff.WindowSettings, s: stuff.FakeZRenderSetup) ?*Window {
                const setup = stuff.ZRenderSetup{
                    .customData = @ptrCast(s.customData),
                    .onDeinit = @ptrCast(s.onDeinit),
                    .onEvent = @ptrCast(s.onEvent),
                    .onRender = @ptrCast(s.onRender),
                };
                const window = ZRenderGL41Window.init(this.allocator, settings, setup) catch |e| {
                    std.io.getStdErr().writer().print("Error creating window: {s}", .{@errorName(e)}) catch return null;
                    return null;
                };
                this.newWindows.append(window) catch return null;
                // If there isn't already an initialized context, initialize it.
                
                // Because OpenGL is stupid and annoying, it HAS to be attached to a window,
                // which is why it is initialized after the window, not before.
                if(this.context == null) {
                    sdl.gl.setAttribute(.{.context_major_version = 4}) catch return null;
                    sdl.gl.setAttribute(.{.context_minor_version = 1}) catch return null;
                    sdl.gl.setAttribute(.{.context_profile_mask = .core}) catch return null;
                    this.context = sdl.gl.createContext(window.sdlWindow) catch return null;
                    gl.load(void{}, loadProc) catch return null;
                    // Make sure we have the GL_ARB_gl_spirv extension
                    // TODO: this is also where we would detect optional extensions and take note of which ones are supported
                    var GL_ARB_gl_spirv = false;
                    var numExtensions: gl.GLint = undefined;
                    gl.getIntegerv(gl.NUM_EXTENSIONS, &numExtensions);
                    for(0 .. @intCast(numExtensions)) |index|{
                        const extension = gl.getStringi(gl.EXTENSIONS, @intCast(index)).?;
                        std.debug.print("OpenGL extension is supported: {s}\n", .{extension});
                        if(std.mem.eql(u8, std.mem.sliceTo(extension, 0), "GL_ARB_gl_spirv")){
                            GL_ARB_gl_spirv = true;
                        }
                    }
                    if(!GL_ARB_gl_spirv) @panic("Missing required OpenGL extension: GL_ARB_gl_spirv");
                    gl.GL_ARB_gl_spirv.load(void{}, loadProc) catch return null;
                }
                return @as(*Window, @ptrCast(window));
            }

            pub fn deinitWindow(this: *ZRenderGL41Instance, window: *ZRenderGL41Window) void {
                this.windowsToDeinit.append(window) catch unreachable;
            }

            pub fn getCustomWindowData(this: *ZRenderGL41Instance, window: *ZRenderGL41Window) *options.CustomWindowData {
                _ = this;
                return window.setup.customData;
            }

            fn actuallyDeinitWindow(this: *ZRenderGL41Instance, window: *ZRenderGL41Window) void {
                // remove the window from the list
                for(this.windows.items, 0..) |window_item, window_index| {
                    if(window_item == window) {
                        _ = this.windows.swapRemove(window_index);
                        break;
                    }
                }
                // deinit the draw queue
                window.queue.deinit();
                // If this was the last window, destroy the OpenGL context as well
                if(this.windows.items.len == 0){
                    sdl.gl.deleteContext(this.context.?);
                }
                window.sdlWindow.destroy();
                // Actually delete the window object
                this.allocator.destroy(window);
            }

            pub fn run(this: *ZRenderGL41Instance) void {
                const instance = Instance.initFromImplementer(ZRenderGL41Instance, this);
                var lastFrameTime = std.time.microTimestamp();
                var currentFrameTime = lastFrameTime;
                // initialize the initial windows, since otherwise the main loop would immediately exit
                for(this.newWindows.items) |newWindow| {
                        this.windows.append(newWindow) catch unreachable;
                    }
                this.newWindows.clearRetainingCapacity();
                // keep running until all of the windows have closed.
                while(this.windows.items.len > 0) {
                    handleEvents(this, currentFrameTime);
                    // Go through the windows that need to be (de)initialized
                    for(this.windowsToDeinit.items) |windowToDeinit| {
                        windowToDeinit.setup.onDeinit(instance, @ptrCast(windowToDeinit), currentFrameTime);
                        actuallyDeinitWindow(this, windowToDeinit);
                    }
                    this.windowsToDeinit.clearRetainingCapacity();
                    for(this.newWindows.items) |newWindow| {
                        this.windows.append(newWindow) catch unreachable;
                    }
                    this.newWindows.clearRetainingCapacity();
                    currentFrameTime = std.time.microTimestamp();
                    const delta = currentFrameTime - lastFrameTime;
                    for(this.windows.items) |window| {
                        window.setup.onRender(instance, @ptrCast(window), @ptrCast(&window.queue), delta, currentFrameTime);
                        // TODO: actually run the queue asynchronously
                        // Or at least run it after all of the windows are finished being iterated.

                        // TODO: verify that this function actually flushes the OpenGL command queue
                        // TODO: it might be worth rendering to a bunch of render buffers, then blitting it to the windows,
                        //  In order to avoid synchronization between the GPU and CPU while the GPU is doing real work,
                        //  However I am not sure if that would actually improve performance so it should be properly tested
                        sdl.gl.makeCurrent(this.context.?, window.sdlWindow) catch @panic("Failed to make window current!");
                        window.queue.run(window);
                    }
                    lastFrameTime = currentFrameTime;
                }
            }

            fn handleEvents(this: *ZRenderGL41Instance, currentFrameTime: i64) void {
                while(sdl.pollEvent()) |event| {
                    switch (event) {
                        .window => |windowEvent| {
                            handleWindowEvent(this, currentFrameTime, windowEvent);
                        },
                        else => {},
                    }
                }
            }

            fn handleWindowEvent(this: *ZRenderGL41Instance, currentFrameTime: i64, event: sdl.WindowEvent) void {
                const instance = Instance.initFromImplementer(ZRenderGL41Instance, this);
                // get the actual window for this event
                var windowOrNone: ?*ZRenderGL41Window = null;
                const id = event.window_id;
                if(sdl.Window.fromID(id)) |sdlWindow| {
                    // Find the actual ZRender window
                    for(this.windows.items) |window| {
                        if(window.sdlWindow.ptr == sdlWindow.ptr) {
                            windowOrNone = window;
                        }
                    }
                }
                // Instead of crashing when the window isn't found,
                // Just return from the function as it's probably not a problem
                if(windowOrNone == null) return;
                var window = windowOrNone.?;
                switch (event.type) {
                    .close => {
                        window.setup.onEvent(instance, @ptrCast(window), .exit, currentFrameTime);
                    },
                    else => {},
                }
            }

            pub fn clearToColor(this: *ZRenderGL41Instance, renderQueue: *GL41RenderQueue, color: stuff.Color) void {
                _ = this;
                renderQueue.items.append(.{
                    .clearToColor = color,
                }) catch unreachable;
            }

            pub fn presentFramebuffer(this: *ZRenderGL41Instance, renderQueue: *GL41RenderQueue, vsync: bool) void {
                _ = this;
                renderQueue.items.append(.{
                    .presentFramebuffer = vsync,
                }) catch unreachable;
            }

            /// Loads a mesh into the GPU. Note that the mesh returned is not loaded immediately, but rather when this queue task runs.
            /// This method does not take ownership of anything. (it copies them)
            pub fn loadMesh(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, t: stuff.MeshType, hint: stuff.MeshUsageHint, attributes: []const stuff.MeshAttribute, vertexBuffer: []const u8, indices: []const u32) ?*stuff.Mesh {
                const mesh = this.allocator.create(GL41Mesh) catch return null;
                mesh.* = .{
                    .initialized = .{
                        .type = t,
                        .attributes = this.allocator.dupe(stuff.MeshAttribute, attributes) catch return null,
                        .vertexBuffer = this.allocator.dupe(u8, vertexBuffer) catch return null,
                        .indices = this.allocator.dupe(u32, indices) catch return null,
                        .usageHint = hint,
                    }
                };
                queue.items.append(GL41RenderQueueItem{
                    .loadMesh = mesh,
                }) catch return null;
                return @ptrCast(mesh);
            }

            /// Returns true if a mesh is loaded. Note that queue methods that take a mesh will block until a mesh is loaded,
            /// And methods on the render queue will not actually run until the setup has exited onFrame.
            /// This method is undefined if a mesh is not live (such as if it was unloaded, or the pointer was not created from loadMesh)
            pub fn isMeshLoaded(this: *ZRenderGL41Instance, mesh_uncast: *stuff.Mesh) bool {
                _ = this;
                const mesh: *GL41Mesh = @alignCast(@ptrCast(mesh_uncast));
                return mesh.* == .loaded;
            }

            pub fn unloadMesh(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, mesh: *GL41Mesh) void {
                _ = this;            
                queue.items.append(GL41RenderQueueItem{
                    .unloadMesh = mesh,
                }) catch unreachable;
            }

            /// Replaces the entirety of the vertex buffer and indices of a mesh.
            pub fn setMeshData(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, mesh: *GL41Mesh, newVertexBuffer: []const u8, indices: []const u32) void {
                queue.items.append(GL41RenderQueueItem {
                    .replaceMeshData = .{
                        .mesh = mesh,
                        .indices = this.allocator.dupe(u32, indices) catch unreachable,
                        .vertexBuffer = this.allocator.dupe(u8, newVertexBuffer) catch unreachable,
                    }
                }) catch unreachable;
            }

            /// Replaces a section of the vertex buffer of a mesh. Start is an offset in bytes.
            pub fn substituteMeshVertexBuffer(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, mesh: *GL41Mesh, start: usize, vertexBuffer: []const u8) void {
                _ = this;
                _ = queue;
                _ = mesh;
                _ = start;
                _ = vertexBuffer;
            
                @panic("Not implemented on the GL41 backend yet");
            }

            /// replaces a section of he indices of a mesh. Start is an offset index.
            pub fn substituteMeshIndices(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, mesh: *GL41Mesh, start: usize, indices: []const u32) void {
                _ = this;
                _ = queue;
                _ = mesh;
                _ = start;
                _ = indices;
            
                @panic("Not implemented on the GL41 backend yet");
            }

            /// Loads a shader program (vertex and fragment shader) from SPIRV binaries.
            /// Assumes the shaders use `main` as the entry point and don't depend on any other binaries.
            pub fn loadShaderProgram(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, attributes: []const stuff.MeshAttribute, vertexSpirvBinary: []const u8, fragmentSpirvBinary: []const u8) ?*stuff.Shader {
                
                const shader = this.allocator.create(GL41ShaderProgram) catch return null;
                
                shader.* = GL41ShaderProgram{
                    .initialized = .{
                        .attributes = this.allocator.dupe(stuff.MeshAttribute, attributes) catch return null,
                        .fragmentSpirvBinary = this.allocator.dupe(u8, fragmentSpirvBinary) catch return null,
                        .vertexSpirvBinary = this.allocator.dupe(u8, vertexSpirvBinary) catch return null,
                    },
                };
                queue.items.append(GL41RenderQueueItem{
                    .loadShader = shader,
                }) catch return null;

                return @ptrCast(shader);
            }

            // TODO: a more advanced shader loading function that allows linking more binaries togther and specifying the entry point

            /// Returns true if a shader is loaded. Note that queue methods that take a shader will block until it is loaded,
            /// And methods on the render queue will not actually run until the setup has exited onFrame.
            /// This method is undefined if a shader is not live (such as if it was unloaded, or the pointer was not created from loadShader)
            pub fn isShaderLoaded(this: *ZRenderGL41Instance, shader: *GL41ShaderProgram) bool {
                _ = this;
                return shader.* == .loaded;
            }

            /// Unloads a shader program
            pub fn unloadShader(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, shader: *GL41ShaderProgram) void {
                _ = this;
                queue.items.append(GL41RenderQueueItem {
                    .unloadShader = shader,
                }) catch unreachable;
            }

            pub fn draw(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, shader: *GL41ShaderProgram, draws: []const stuff.DrawInstance) void {
                const drawsMarshalled = this.allocator.alloc(stuff.DrawInstance, draws.len) catch unreachable;
                for(0 .. drawsMarshalled.len) |index| {
                    drawsMarshalled[index] = draws[index].dupe(this.allocator);
                }
                queue.items.append(
                    GL41RenderQueueItem{
                        .draw = .{
                            .shader = shader,
                            .draws = drawsMarshalled,
                        }
                    }
                ) catch unreachable;
            }
        };

        const ZRenderGL41Window = struct {
            sdlWindow: sdl.Window,
            setup: stuff.ZRenderSetup,
            queue: GL41RenderQueue,

            pub fn init(allocator: std.mem.Allocator, settings: stuff.WindowSettings, setup: stuff.ZRenderSetup) !*ZRenderGL41Window {
                const xPos:sdl.WindowPosition = blk: {
                    if(settings.xPos == null) break :blk .default
                    else break :blk .{.absolute = @intCast(settings.xPos.?)};
                };
                const yPos:sdl.WindowPosition = blk: {
                    if(settings.yPos == null) break :blk .default
                    else break :blk .{.absolute = @intCast(settings.yPos.?)};
                };
                const w = ZRenderGL41Window{
                    .sdlWindow = try sdl.createWindow(settings.name, xPos, yPos, @intCast(settings.width), @intCast(settings.height), .{
                        .resizable = settings.resizable,
                        .context = .opengl,
                    }),
                    .setup = setup,
                    .queue = GL41RenderQueue.init(allocator),
                };
                const object = try allocator.create(ZRenderGL41Window);
                object.* = w;
                return object;
            }
        };

        const GL41Mesh = union(enum) {
            loaded: struct {
                /// The number of indices
                indexCount: u32,
                /// The handle to the OpenGL buffer object containing the indices
                indexBufferObject: gl.GLuint,
                /// The number of bytes contained in the vertices buffer
                verticesBufferSize: u32,
                /// The handle to the OpenGL buffer object containing the vertices
                vertexBufferObject: gl.GLuint,
                /// The handle to the OpenGL vertex array object
                vertexArrayObject: gl.GLuint,
                /// Mesh usage hint
                usageHint: stuff.MeshUsageHint,
                /// What type of mesh this is
                type: stuff.MeshType,
                /// The mesh attributes, this memory matches the lifetime of the OpenGL object.
                attributes: []const stuff.MeshAttribute,
            },
            initialized: struct {
                type: stuff.MeshType,
                attributes: []const stuff.MeshAttribute,
                vertexBuffer: []const u8,
                indices: []const u32,
                usageHint: stuff.MeshUsageHint,
            },
            /// Takes ownership and frees the data given to it. Assumes it's already loaded.
            pub fn replaceData(self: *GL41Mesh, allocator: std.mem.Allocator, vertexBuffer: []const u8, indices: []const u32) void {
                // TODO: read up on the different OpenGL usage hints
                const glUsageHint: gl.GLenum = switch (self.loaded.usageHint) {
                    .cold => gl.STATIC_DRAW,
                    .render => gl.STATIC_DRAW,
                    .write => gl.DYNAMIC_DRAW,
                    .render_write => gl.DYNAMIC_DRAW,
                };
                self.loaded.indexCount = @intCast(indices.len);
                self.loaded.verticesBufferSize = @intCast(vertexBuffer.len);
                gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.loaded.indexBufferObject);
                gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr,glUsageHint);
                gl.bindBuffer(gl.ARRAY_BUFFER, self.loaded.vertexBufferObject);
                gl.bufferData(gl.ARRAY_BUFFER, @intCast(vertexBuffer.len), vertexBuffer.ptr, glUsageHint);
                allocator.free(vertexBuffer);
                allocator.free(indices);
            }

            pub fn load(self: *GL41Mesh, allocator: std.mem.Allocator) void {
                switch (self.*) {
                    .loaded => return,
                    .initialized => |init| {
                        // TODO: It might be worth consolidating loadMesh queue items into a single batch of them.
                        var vao: gl.GLuint = undefined;
                        gl.genVertexArrays(1, &vao);
                        gl.bindVertexArray(vao);
                        var buffers = [2]gl.GLuint{undefined, undefined}; 
                        gl.genBuffers(2, &buffers);
                        const vbo = buffers[0];
                        const ibo = buffers[1];
                        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
                        // TODO: read up on the different OpenGL usage hints
                        const glUsageHint: gl.GLenum = switch (init.usageHint) {
                            .cold => gl.STATIC_DRAW,
                            .render => gl.STATIC_DRAW,
                            .write => gl.DYNAMIC_DRAW,
                            .render_write => gl.DYNAMIC_DRAW,
                        };
                        gl.bufferData(gl.ARRAY_BUFFER, @intCast(init.vertexBuffer.len), init.vertexBuffer.ptr, glUsageHint);
                        
                        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
                        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(init.indices.len * @sizeOf(u32)), init.indices.ptr, glUsageHint);

                        var totalAttrib: usize = 0;
                        for(init.attributes) |attribute| {
                            totalAttrib += attribSize(attribute);
                        }

                        var runningTotalAttrib: usize = 0;
                        for(init.attributes, 0..) |attrib, i| {
                            const attribute = attribSize(attrib);
                            gl.enableVertexAttribArray(@intCast(i));
                            if(attribIsInt(attrib))
                                gl.vertexAttribIPointer(@intCast(i), attribElements(attrib), attribToGLenum(attrib), @intCast(totalAttrib), @ptrFromInt(runningTotalAttrib))
                            else
                                gl.vertexAttribPointer(@intCast(i), attribElements(attrib), attribToGLenum(attrib), 0, @intCast(totalAttrib), @ptrFromInt(runningTotalAttrib));
                            runningTotalAttrib += attribute;
                        }
                        
                        const n = GL41Mesh{
                            .loaded = .{
                                .indexCount = @intCast(init.indices.len),
                                .indexBufferObject = ibo,
                                .verticesBufferSize = @intCast(init.vertexBuffer.len),
                                .vertexBufferObject = vbo,
                                .vertexArrayObject = vao,
                                .usageHint = init.usageHint,
                                .type = init.type,
                                .attributes = init.attributes,
                            }
                        };
                        allocator.free(init.indices);
                        allocator.free(init.vertexBuffer);
                        self.* = n;
                    },
                }   
            }
            pub fn unload(self: *@This(), allocator: std.mem.Allocator) void {
                switch (self.*) {
                    .loaded => |l| {
                        allocator.free(l.attributes);
                        var buffers = [2]gl.GLuint{l.vertexBufferObject, l.indexBufferObject}; 
                        gl.deleteBuffers(2, &buffers);
                        gl.deleteVertexArrays(1, &l.vertexArrayObject);
                    },
                    .initialized => @panic("Cannot unload a mesh that has not finished loading"),
                }
                allocator.destroy(self);
            }
        };

        const GL41ShaderProgram = union(enum) {
            initialized: struct {
                attributes: []const stuff.MeshAttribute,
                vertexSpirvBinary: []const u8,
                fragmentSpirvBinary: []const u8,
            },
            loaded: struct {
                attributes: []const stuff.MeshAttribute,
                /// The OpenGL shader program object
                program: gl.GLuint,
            },

            pub fn load(self: *GL41ShaderProgram, allocator: std.mem.Allocator) bool {
                switch (self.*) {
                    .initialized => |init| {
                        const vertexShader = gl.createShader(gl.VERTEX_SHADER);
                        defer gl.deleteShader(vertexShader);
                        gl.shaderBinary(1, &vertexShader, gl.GL_ARB_gl_spirv.SHADER_BINARY_FORMAT_SPIR_V_ARB, init.vertexSpirvBinary.ptr, @intCast(init.vertexSpirvBinary.len));
                        gl.GL_ARB_gl_spirv.specializeShaderARB(vertexShader, "main", 0, null, null);
                        var vertexShaderSuccess: gl.GLint = undefined;
                        gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &vertexShaderSuccess);
                        if(vertexShaderSuccess == gl.FALSE) {
                            // TODO: get error message and put it somewhere useful
                            return false;
                        }

                        const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
                        defer gl.deleteShader(fragmentShader);
                        gl.shaderBinary(1, &fragmentShader, gl.GL_ARB_gl_spirv.SHADER_BINARY_FORMAT_SPIR_V_ARB, init.fragmentSpirvBinary.ptr, @intCast(init.fragmentSpirvBinary.len));
                        gl.GL_ARB_gl_spirv.specializeShaderARB(fragmentShader, "main", 0, null, null);
                        var fragmentShaderSuccess: gl.GLint = undefined;
                        gl.getShaderiv(vertexShader, gl.COMPILE_STATUS, &fragmentShaderSuccess);
                        if(fragmentShaderSuccess == gl.FALSE) {
                            return false;
                        }

                        const program = gl.createProgram();
                        gl.attachShader(program, vertexShader);
                        gl.attachShader(program, fragmentShader);
                        gl.linkProgram(program);
                        var linkSuccess:gl.GLint = undefined;
                        gl.getProgramiv(program, gl.LINK_STATUS, &linkSuccess);
                        if(linkSuccess == gl.FALSE) {
                            gl.deleteProgram(program);
                            return false;
                        }
                        gl.detachShader(program, vertexShader);
                        gl.detachShader(program, fragmentShader);
                        allocator.free(init.fragmentSpirvBinary);
                        allocator.free(init.vertexSpirvBinary);
                        self.* = .{
                            .loaded = .{
                                .attributes = init.attributes,
                                .program = program,
                            }
                        };
                        return true;

                    },
                    .loaded => return true,
                }
            }

            pub fn unload(self: *GL41ShaderProgram, allocator: std.mem.Allocator) void {
                allocator.free(self.loaded.attributes);
                gl.deleteProgram(self.loaded.program);
                allocator.destroy(self);
            }
        };

        fn attribSize(attrib: stuff.MeshAttribute) usize {
            return switch (attrib) {
                .@"bool" => @sizeOf(gl.GLubyte),
                .int => @sizeOf(gl.GLint),
                .uint => @sizeOf(gl.GLuint),
                .float => @sizeOf(gl.GLfloat),
                .bvec2 => @sizeOf(gl.GLubyte) * 2,
                .ivec2 => @sizeOf(gl.GLint) * 2,
                .uvec2 => @sizeOf(gl.GLuint) * 2,
                .vec2 => @sizeOf(gl.GLfloat) * 2,
                .bvec3 => @sizeOf(gl.GLubyte) * 3,
                .ivec3 => @sizeOf(gl.GLint) * 3,
                .uvec3 => @sizeOf(gl.GLuint) * 3,
                .vec3 => @sizeOf(gl.GLfloat) * 3,
                .bvec4 => @sizeOf(gl.GLubyte) * 4,
                .ivec4 => @sizeOf(gl.GLint) * 4,
                .uvec4 => @sizeOf(gl.GLuint) * 4,
                .vec4 => @sizeOf(gl.GLfloat) * 4,
            };
        }

        fn attribToGLenum(attrib: stuff.MeshAttribute) gl.GLenum {
            return switch (attrib) {
                .@"bool" => gl.UNSIGNED_BYTE,
                .int => gl.INT,
                .uint => gl.UNSIGNED_INT,
                .float => gl.FLOAT,
                .bvec2 => gl.UNSIGNED_BYTE,
                .ivec2 => gl.INT,
                .uvec2 => gl.UNSIGNED_INT,
                .vec2 => gl.FLOAT,
                .bvec3 => gl.UNSIGNED_BYTE,
                .ivec3 => gl.INT,
                .uvec3 => gl.UNSIGNED_INT,
                .vec3 => gl.FLOAT,
                .bvec4 => gl.UNSIGNED_BYTE,
                .ivec4 => gl.INT,
                .uvec4 => gl.UNSIGNED_INT,
                .vec4 => gl.FLOAT,
            };
        }

        fn attribElements(attrib: stuff.MeshAttribute) gl.GLint {
            return switch (attrib) {
                .@"bool" => 1,
                .int => 1,
                .uint => 1,
                .float => 1,
                .bvec2 => 2,
                .ivec2 => 2,
                .uvec2 => 2,
                .vec2 => 2,
                .bvec3 => 3,
                .ivec3 => 3,
                .uvec3 => 3,
                .vec3 => 3,
                .bvec4 => 4,
                .ivec4 => 4,
                .uvec4 => 4,
                .vec4 => 4,
            };
        }

        fn attribIsInt(attrib: stuff.MeshAttribute) bool {
            return switch (attrib) {
                .@"bool" => true,
                .int => true,
                .uint => true,
                .float => false,
                .bvec2 => true,
                .ivec2 => true,
                .uvec2 => true,
                .vec2 => false,
                .bvec3 => true,
                .ivec3 => true,
                .uvec3 => true,
                .vec3 => false,
                .bvec4 => true,
                .ivec4 => true,
                .uvec4 => true,
                .vec4 => false,
            };
        }

        const GL41RenderQueueItem = union(enum) {
            clearToColor: stuff.Color,
            /// the bool is vsync
            presentFramebuffer: bool,
            loadMesh: *GL41Mesh,
            unloadMesh: *GL41Mesh,
            loadShader: *GL41ShaderProgram,
            unloadShader: *GL41ShaderProgram,
            draw: struct {
                shader: *GL41ShaderProgram,
                draws: []const stuff.DrawInstance,
            },
            replaceMeshData: struct {
                mesh: *GL41Mesh,
                vertexBuffer: []const u8,
                indices: []const u32,
            },
        };

        const GL41RenderQueue = struct {
            // TODO: use a dependency tree instead of a list
            // TODO: (far future) optimize queue items a bit, such as combining overlapping clears.
            items: std.ArrayList(GL41RenderQueueItem),
            
            pub fn init(allocator: std.mem.Allocator) @This() {
                return @This() {
                    .items = std.ArrayList(GL41RenderQueueItem).init(allocator),
                };
            }

            pub fn deinit(this: @This()) void {
                this.items.deinit();
            }

            /// Runs the queue on the current OpenGL context and window, then clears the queue.
            pub fn run(this: *@This(), window: *ZRenderGL41Window) void {
                for(this.items.items) |item| {
                    switch (item) {
                        .clearToColor => |color| {
                            gl.clearColor(@as(f32, @floatFromInt(color.r)) / 256.0, @as(f32,@floatFromInt(color.g)) / 256.0, @as(f32, @floatFromInt(color.b)) / 256.0, @as(f32, @floatFromInt(color.a)) / 256.0);
                            gl.clear(gl.COLOR_BUFFER_BIT);
                        },
                        .presentFramebuffer => |vsync| {
                            if(vsync) {
                                sdl.gl.setSwapInterval(.adaptive_vsync) catch @panic("Could not set swap interval to adaptive sync");
                            } else {
                                sdl.gl.setSwapInterval(.immediate) catch @panic("Could not set swap interval to immediate");
                            }
                            sdl.gl.swapWindow(window.sdlWindow);
                        },
                        .loadMesh => |mesh| {
                            mesh.load(this.items.allocator);
                        },
                        .unloadMesh => |mesh| {
                            mesh.unload(this.items.allocator);
                        },
                        .loadShader => |shader| {
                            if(!shader.load(this.items.allocator)) std.debug.print("Error loading shader", .{});
                        },
                        .unloadShader => |shader| {
                            shader.unload(this.items.allocator);
                        },
                        .draw => |d| {
                            draw(d.shader, d.draws, this.items.allocator);
                        },
                        .replaceMeshData => |data| {
                            data.mesh.replaceData(this.items.allocator, data.vertexBuffer, data.indices);
                        },
                    }
                }
                this.items.clearRetainingCapacity();
            }

            fn draw(shader: *GL41ShaderProgram, draws: []const stuff.DrawInstance, allocator: std.mem.Allocator) void {
                gl.useProgram(shader.loaded.program);
                // TODO: instanced drawing instead of a separate draw call for every mesh.
                for(draws) |instance| {
                    const mesh: *GL41Mesh = @alignCast(@ptrCast(instance.mesh));
                    // Make sure the mesh and shader have identical attributes
                    if(!std.mem.eql(stuff.MeshAttribute, mesh.loaded.attributes, shader.loaded.attributes)) {
                        // TODO: make an error and put it somewhere useful instead of just crashing
                        @panic("Shader attributes don't match mesh attributes");
                    }
                    gl.bindVertexArray(mesh.loaded.vertexArrayObject);
                    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.loaded.indexBufferObject);
                    gl.bindBuffer(gl.ARRAY_BUFFER, mesh.loaded.vertexBufferObject);

                    const drawMethod: gl.GLenum = switch (mesh.loaded.type) {
                        .triangles => gl.TRIANGLES,
                        .quads => gl.QUADS,
                    };
                    const numElements = @min(instance.numElements, mesh.loaded.indexCount - instance.startElement);
                    gl.drawElements(drawMethod, @intCast(numElements), gl.UNSIGNED_INT, @ptrFromInt(instance.startElement * @sizeOf(u32)));
                    // TODO: uniforms
                }
                // free the draw objects
                for(draws) |instance| {
                    allocator.free(instance.uniforms);
                }
                allocator.free(draws);
            }
        };
    };
}