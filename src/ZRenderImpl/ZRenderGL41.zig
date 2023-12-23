const std = @import("std");
pub const gl = @import("ext/GL41Bind.zig");
const sdl = @import("sdl");
const ZRenderOptions = @import("ZRenderOptions.zig");

fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
    _ = ctx;
    return sdl.gl.getProcAddress(name);
}
pub fn ZRenderGL41(comptime options: ZRenderOptions) type {
    return struct {
        const impl = @import("ZRenderImpl.zig");
        const stuff = impl.Stuff(options);
        // some 'static includes' because yeah
        const Instance = stuff.Instance;
        const Window = impl.Window;
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

            pub fn initWindow(this: *ZRenderGL41Instance, settings: impl.WindowSettings, s: stuff.FakeZRenderSetup) ?*Window {
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

            pub fn clearToColor(this: *ZRenderGL41Instance, renderQueue: *GL41RenderQueue, color: impl.Color) void {
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
            pub fn loadMesh(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, t: impl.MeshType, hint: impl.MeshUsageHint, attributes: []const impl.MeshAttribute, vertexBuffer: []const u8, indices: []const u32) ?*impl.Mesh {
                const mesh = this.allocator.create(GL41Mesh) catch return null;
                mesh.* = .{
                    .initialized = .{
                        .type = t,
                        .attributes = this.allocator.dupe(impl.MeshAttribute, attributes) catch return null,
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
            pub fn isMeshLoaded(this: *ZRenderGL41Instance, mesh_uncast: *impl.Mesh) bool {
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
                queue.items.append(GL41RenderQueueItem{
                    .substituteMeshVertexBuffer = .{
                        .mesh = mesh,
                        .start = start,
                        .vertexBuffer = this.allocator.dupe(u8, vertexBuffer) catch unreachable,
                    }
                }) catch unreachable;
            }

            /// replaces a section of he indices of a mesh. Start is an offset index.
            pub fn substituteMeshIndices(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, mesh: *GL41Mesh, start: usize, indices: []const u32) void {
                queue.items.append(GL41RenderQueueItem{
                    .substituteMeshIndices = .{
                        .mesh = mesh,
                        .start = start,
                        .indices = this.allocator.dupe(u32, indices) catch unreachable,
                    }
                }) catch unreachable;
            }

            /// Loads a shader program (vertex and fragment shader) from SPIRV binaries.
            /// Assumes the shaders use `main` as the entry point and don't depend on any other binaries.
            pub fn loadShaderProgram(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, attributes: []const impl.MeshAttribute, vertexSpirvBinary: []const u8, fragmentSpirvBinary: []const u8) ?*impl.Shader {
                
                const shader = this.allocator.create(GL41ShaderProgram) catch return null;
                
                shader.* = GL41ShaderProgram{
                    .initialized = .{
                        .attributes = this.allocator.dupe(impl.MeshAttribute, attributes) catch return null,
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

            pub fn draw(this: *ZRenderGL41Instance, queue: *GL41RenderQueue, shader: *GL41ShaderProgram, draws: []const impl.DrawInstance) void {
                const drawsMarshalled = this.allocator.alloc(impl.DrawInstance, draws.len) catch unreachable;
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

            pub fn init(allocator: std.mem.Allocator, settings: impl.WindowSettings, setup: stuff.ZRenderSetup) !*ZRenderGL41Window {
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

        pub const GL41Mesh = @import("ZRenderGL41/mesh.zig").GL41Mesh;

        const GL41ShaderProgram = union(enum) {
            initialized: struct {
                attributes: []const impl.MeshAttribute,
                vertexSpirvBinary: []const u8,
                fragmentSpirvBinary: []const u8,
            },
            loaded: struct {
                attributes: []const impl.MeshAttribute,
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

        const GL41RenderQueueItem = union(enum) {
            clearToColor: impl.Color,
            /// the bool is vsync
            presentFramebuffer: bool,
            loadMesh: *GL41Mesh,
            unloadMesh: *GL41Mesh,
            loadShader: *GL41ShaderProgram,
            unloadShader: *GL41ShaderProgram,
            draw: struct {
                shader: *GL41ShaderProgram,
                draws: []const impl.DrawInstance,
            },
            replaceMeshData: struct {
                mesh: *GL41Mesh,
                vertexBuffer: []const u8,
                indices: []const u32,
            },
            substituteMeshVertexBuffer: struct {
                mesh: *GL41Mesh,
                start: usize,
                vertexBuffer: []const u8,
            },
            substituteMeshIndices: struct {
                mesh: *GL41Mesh,
                start: usize,
                indices: []const u32
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
                        .substituteMeshVertexBuffer => |data| {
                            data.mesh.subVertexBuffer(data.start, data.vertexBuffer);
                            this.items.allocator.free(data.vertexBuffer);
                        },
                        .substituteMeshIndices => |data| {
                            data.mesh.subIndices(data.start, data.indices);
                            this.items.allocator.free(data.indices);
                        },
                    }
                }
                this.items.clearRetainingCapacity();
            }

            fn draw(shader: *GL41ShaderProgram, draws: []const impl.DrawInstance, allocator: std.mem.Allocator) void {
                gl.useProgram(shader.loaded.program);
                // TODO: instanced drawing instead of a separate draw call for every mesh.
                for(draws) |instance| {
                    const mesh: *GL41Mesh = @alignCast(@ptrCast(instance.mesh));
                    // Make sure the mesh and shader have identical attributes
                    if(!std.mem.eql(impl.MeshAttribute, mesh.loaded.attributes, shader.loaded.attributes)) {
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