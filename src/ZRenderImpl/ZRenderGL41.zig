const std = @import("std");
pub const gl = @import("ext/GL41Bind.zig");
const sdl = @import("sdl");
const ZRenderOptions = @import("ZRenderOptions.zig");
const impl = @import("ZRenderImpl.zig");

const glMesh = @import("ZRenderGL41/mesh.zig");
const glShader = @import("ZRenderGL41/shader.zig");
const glQueue = @import("ZRenderGL41/queue.zig");

pub fn ZRenderGL41(comptime options: ZRenderOptions) type {
    return struct {
        const stuff = impl.Stuff(options);
        // some 'static includes' because yeah
        const Instance = stuff.Instance;
        const Window = impl.Window;
        pub fn initInstance(allocator: std.mem.Allocator, customData: *options.CustomInstanceData) !Instance {
            
            try sdl.init(.{.video = true});
            const obj = ZRenderGL41Instance{
                .allocator = allocator,
                .windows = std.ArrayList(*GL41Window).init(allocator),
                .newWindows = std.ArrayList(*GL41Window).init(allocator),
                .windowsToDeinit = std.ArrayList(*GL41Window).init(allocator),
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
            windows: std.ArrayList(*GL41Window),
            // Windows that have been created but not added to the list of windows
            newWindows: std.ArrayList(*GL41Window),
            // Windows that have been queued to be deleted.
            windowsToDeinit: std.ArrayList(*GL41Window),

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
                const window = GL41Window.init(this.allocator, settings, setup) catch |e| {
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

            pub fn deinitWindow(this: *ZRenderGL41Instance, window: *GL41Window) void {
                this.windowsToDeinit.append(window) catch unreachable;
            }

            pub fn getCustomWindowData(this: *ZRenderGL41Instance, window: *GL41Window) *options.CustomWindowData {
                _ = this;
                return window.setup.customData;
            }

            fn actuallyDeinitWindow(this: *ZRenderGL41Instance, window: *GL41Window) void {
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
                var windowOrNone: ?*GL41Window = null;
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
        const GL41Mesh = glMesh.GL41Mesh;
        const GL41ShaderProgram = glShader.GL41ShaderProgram;
        const GL41RenderQueue = glQueue.GL41RenderQueue;
        const GL41RenderQueueItem = glQueue.GL41RenderQueueItem;

        pub const GL41Window = struct {
            sdlWindow: sdl.Window,
            setup: stuff.ZRenderSetup,
            queue: GL41RenderQueue,

            pub fn init(allocator: std.mem.Allocator, settings: impl.WindowSettings, setup: stuff.ZRenderSetup) !*GL41Window {
                const xPos:sdl.WindowPosition = blk: {
                    if(settings.xPos == null) break :blk .default
                    else break :blk .{.absolute = @intCast(settings.xPos.?)};
                };
                const yPos:sdl.WindowPosition = blk: {
                    if(settings.yPos == null) break :blk .default
                    else break :blk .{.absolute = @intCast(settings.yPos.?)};
                };
                const w = GL41Window{
                    .sdlWindow = try sdl.createWindow(settings.name, xPos, yPos, @intCast(settings.width), @intCast(settings.height), .{
                        .resizable = settings.resizable,
                        .context = .opengl,
                    }),
                    .setup = setup,
                    .queue = GL41RenderQueue.init(allocator),
                };
                const object = try allocator.create(GL41Window);
                object.* = w;
                return object;
            }

            /// presents the framebuffer, assumes a current OpenGL context and window
            pub fn presentFramebuffer(window: anytype, vsync: bool) void {
                if(vsync) {
                    sdl.gl.setSwapInterval(.adaptive_vsync) catch @panic("Could not set swap interval to adaptive sync");
                } else {
                    sdl.gl.setSwapInterval(.immediate) catch @panic("Could not set swap interval to immediate");
                }
                sdl.gl.swapWindow(window.sdlWindow);
            }
        };

        fn loadProc(ctx: void, name: [:0]const u8) ?gl.FunctionPointer {
            _ = ctx;
            return sdl.gl.getProcAddress(name);
        }
    };
}