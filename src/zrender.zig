const std = @import("std");
const zengine = @import("zengine");
const ecs = @import("ecs");

const c = @cImport({
    @cInclude("kinc/graphics4/graphics.h");
    @cInclude("kinc/graphics4/indexbuffer.h");
    @cInclude("kinc/graphics4/pipeline.h");
    @cInclude("kinc/graphics4/shader.h");
    @cInclude("kinc/graphics4/vertexbuffer.h");
    @cInclude("kinc/graphics4/texture.h");
    @cInclude("kinc/system.h");
    @cInclude("kinc/input/keyboard.h");
    @cInclude("kinc/input/mouse.h");
});

pub const RenderComponent = struct { mesh: MeshHandle, texture: TextureHandle, pipeline: PipelineHandle, transform: Mat4 };

pub const VertexAttribute = enum(c_uint) {
    none = c.KINC_G4_VERTEX_DATA_NONE,
    /// equivalent to GLSL float
    f32 = c.KINC_G4_VERTEX_DATA_F32_1X,
    /// equivalent to GLSL vec2
    f32x2 = c.KINC_G4_VERTEX_DATA_F32_2X,
    /// equivalent to GLSL vec3
    f32x3 = c.KINC_G4_VERTEX_DATA_F32_3X,
    /// equivalent to GLSL vec4
    f32x4 = c.KINC_G4_VERTEX_DATA_F32_4X,
    /// equivalent to GLSL mat4
    f32x4x4 = c.KINC_G4_VERTEX_DATA_F32_4X4,
    i8 = c.KINC_G4_VERTEX_DATA_I8_1X,
    u8 = c.KINC_G4_VERTEX_DATA_U8_1X,
    i8normalized = c.KINC_G4_VERTEX_DATA_I8_1X_NORMALIZED,
    u8normalized = c.KINC_G4_VERTEX_DATA_U8_1X_NORMALIZED,
    i8x2 = c.KINC_G4_VERTEX_DATA_I8_2X,
    u8x2 = c.KINC_G4_VERTEX_DATA_U8_2X,
    i8x2normalized = c.KINC_G4_VERTEX_DATA_I8_2X_NORMALIZED,
    u8x2normalized = c.KINC_G4_VERTEX_DATA_U8_2X_NORMALIZED,
    i8x4 = c.KINC_G4_VERTEX_DATA_I8_4X,
    u8x4 = c.KINC_G4_VERTEX_DATA_U8_4X,
    i8x4normalized = c.KINC_G4_VERTEX_DATA_I8_4X_NORMALIZED,
    u8x4normalized = c.KINC_G4_VERTEX_DATA_U8_4X_NORMALIZED,
    i16 = c.KINC_G4_VERTEX_DATA_I16_1X,
    u16 = c.KINC_G4_VERTEX_DATA_U16_1X,
    i16normalized = c.KINC_G4_VERTEX_DATA_I16_1X_NORMALIZED,
    u16normalized = c.KINC_G4_VERTEX_DATA_U16_1X_NORMALIZED,
    i16x2 = c.KINC_G4_VERTEX_DATA_I16_2X,
    u16x2 = c.KINC_G4_VERTEX_DATA_U16_2X,
    i16x2normalized = c.KINC_G4_VERTEX_DATA_I16_2X_NORMALIZED,
    u16x2normalized = c.KINC_G4_VERTEX_DATA_U16_2X_NORMALIZED,
    i16x4 = c.KINC_G4_VERTEX_DATA_I16_4X,
    u16x4 = c.KINC_G4_VERTEX_DATA_U16_4X,
    i16x4normalized = c.KINC_G4_VERTEX_DATA_I16_4X_NORMALIZED,
    u16x4normalized = c.KINC_G4_VERTEX_DATA_U16_4X_NORMALIZED,
    i32 = c.KINC_G4_VERTEX_DATA_I32_1X,
    u32 = c.KINC_G4_VERTEX_DATA_U32_1X,
    i32x2 = c.KINC_G4_VERTEX_DATA_I32_2X,
    u32x2 = c.KINC_G4_VERTEX_DATA_U32_2X,
    i32x3 = c.KINC_G4_VERTEX_DATA_I32_3X,
    u32x3 = c.KINC_G4_VERTEX_DATA_U32_3X,
    i32x4 = c.KINC_G4_VERTEX_DATA_I32_4X,
    u32x4 = c.KINC_G4_VERTEX_DATA_U32_4X,
};

pub const NamedVertexAttribute = struct {
    name: [:0]const u8,
    type: VertexAttribute,
};

pub const PipelineArgs = struct {
    attributes: []const NamedVertexAttribute,
};

pub const MeshHandle = struct {
    rawHandle: usize,
    numVertices: usize,
    numIndices: usize,
};

pub const TextureHandle = usize;

pub const PipelineHandle = usize;

pub const Mat4 = extern struct {
    m00: f32,
    m01: f32,
    m02: f32,
    m03: f32,
    m10: f32,
    m11: f32,
    m12: f32,
    m13: f32,
    m20: f32,
    m21: f32,
    m22: f32,
    m23: f32,
    m30: f32,
    m31: f32,
    m32: f32,
    m33: f32,

    pub const identity = Mat4{
        .m00 = 1,
        .m01 = 0,
        .m02 = 0,
        .m03 = 0,
        .m10 = 0,
        .m11 = 1,
        .m12 = 0,
        .m13 = 0,
        .m20 = 0,
        .m21 = 0,
        .m22 = 1,
        .m23 = 0,
        .m30 = 0,
        .m31 = 0,
        .m32 = 0,
        .m33 = 1,
    };
};

/// ZEngine rendering system
pub const ZRenderSystem = struct {
    pub const name: []const u8 = "zrender";
    pub const components = [_]type{RenderComponent};
    pub fn comptimeVerification(comptime options: zengine.ZEngineComptimeOptions) bool {
        // TODO
        _ = options;
        return true;
    }

    pub fn init(staticAllocator: std.mem.Allocator, heapAllocator: std.mem.Allocator) @This() {
        _ = staticAllocator;
        return ZRenderSystem{
            .pipelines = std.ArrayList(?Pipeline).init(heapAllocator),
            .pipelineSpots = std.ArrayList(usize).init(heapAllocator),
            .meshes = std.ArrayList(?Mesh).init(heapAllocator),
            .meshSpots = std.ArrayList(usize).init(heapAllocator),
            .textures = std.ArrayList(?Texture).init(heapAllocator),
            .textureSpots = std.ArrayList(TextureHandle).init(heapAllocator),
            .allocator = heapAllocator,
            .onFrame = ecs.Signal(OnFrameEventArgs).init(heapAllocator),
            .onUpdate = ecs.Signal(OnUpdateEventArgs).init(heapAllocator),
            .updateTime = std.time.microTimestamp(),
            .lastFrameTime = std.time.microTimestamp(),
            .onMouseEnterWindow = ecs.Signal(OnMouseEnterWindowEventArgs).init(heapAllocator),
            .onMouseLeaveWindow = ecs.Signal(OnMouseLeaveWindowEventArgs).init(heapAllocator),
            .onMousePress = ecs.Signal(OnMousePressEventArgs).init(heapAllocator),
            .onMouseRelease = ecs.Signal(OnMouseReleaseEventArgs).init(heapAllocator),
            .onMouseMove = ecs.Signal(OnMouseMoveEventArgs).init(heapAllocator),
            .onMouseScroll = ecs.Signal(OnMouseScrollEventArgs).init(heapAllocator),
            .onKeyDown = ecs.Signal(OnKeyDownEventArgs).init(heapAllocator),
            .onKeyUp = ecs.Signal(OnKeyUpEventArgs).init(heapAllocator),
            .onType = ecs.Signal(OnTypeEventArgs).init(heapAllocator),
        };
    }

    pub fn systemInitGlobal(this: *@This(), registries: *zengine.RegistrySet) !void {
        try this.initZRender(registries);
    }

    pub fn systemDeinitGlobal(this: *@This(), registries: *zengine.RegistrySet) void {
        // TODO: deinit all of the actual GPU objects
        // Side note, I thought the Vulkan validation layers would catch GPU memory leaks. I guess they don't.
        // but I can simply use apitrace or whatever the Vulkan equivalent of that is.
        _ = registries;
        _ = this;
    }

    pub fn deinit(this: *@This()) void {
        this.pipelines.deinit();
        this.pipelineSpots.deinit();
        this.meshes.deinit();
        this.meshSpots.deinit();
        this.textures.deinit();
        this.textureSpots.deinit();
        this.onFrame.deinit();
        this.onUpdate.deinit();
        this.onMouseEnterWindow.deinit();
        this.onMouseLeaveWindow.deinit();
        this.onMousePress.deinit();
        this.onMouseRelease.deinit();
        this.onMouseMove.deinit();
        this.onMouseScroll.deinit();
        this.onKeyDown.deinit();
        this.onKeyUp.deinit();
        this.onType.deinit();
    }

    fn initZRender(this: *@This(), registries: *zengine.RegistrySet) !void {
        _ = this;
        _ = c.kinc_init("ZRender", 1024, 768, null, null);
        c.kinc_set_update_callback(&update, registries);

        c.kinc_mouse_set_enter_window_callback(&mouse_enter_window, registries);
        c.kinc_mouse_set_leave_window_callback(&mouse_leave_window, registries);
        c.kinc_mouse_set_press_callback(&mouse_press, registries);
        c.kinc_mouse_set_release_callback(&mouse_release, registries);
        c.kinc_mouse_set_move_callback(&mouse_move, registries);
        c.kinc_mouse_set_scroll_callback(&mouse_scroll, registries);
        c.kinc_keyboard_set_key_down_callback(&key_down, registries);
        c.kinc_keyboard_set_key_up_callback(&key_up, registries);
        c.kinc_keyboard_set_key_press_callback(&key_press, registries);
    }

    pub fn loadTexture(this: *@This(), data: []const u8) !TextureHandle {
        const texture = try this._loadTexture(data);
        // get a free handle
        const handle = blk: {
            if (this.textureSpots.items.len > 0) {
                break :blk this.textureSpots.pop();
            } else {
                const temp = this.textures.items.len;
                _ = try this.textures.addOne();
                break :blk temp;
            }
        };
        this.textures.items[handle] = texture;
        return handle;
    }

    pub fn unloadTexture(this: *@This(), handle: TextureHandle) void {
        const texture = this.textures.items[handle].?;
        this.textureSpots.append(handle);
        this.textures.items[handle] = null;
        this._unloadTexture(texture);
        return;
    }

    pub fn loadMesh(this: *@This(), Vertex: type, vertices: []const Vertex, indices: []const u16, pipelineHandle: PipelineHandle) !MeshHandle {
        const pipeline = &this.pipelines.items[pipelineHandle].?;
        const mesh = this._loadMesh(Vertex, vertices, indices, pipeline);
        // get a free handle
        const rawHandle = blk: {
            if (this.meshes.items.len > 0) {
                break :blk this.meshSpots.pop();
            } else {
                const temp = this.textures.items.len;
                _ = try this.meshes.addOne();
                break :blk temp;
            }
        };
        this.meshes.items[rawHandle] = mesh;
        return MeshHandle{
            .rawHandle = rawHandle,
            .numVertices = vertices.len,
            .numIndices = indices.len,
        };
    }

    pub fn mapMeshVertices(this: *@This(), Vertex: type, handle: MeshHandle, startVertex: usize, count: usize) []Vertex {
        var mesh = this.meshes.items[handle.rawHandle].?;
        var data: []Vertex = undefined;
        data.ptr = @ptrCast(c.kinc_g4_vertex_buffer_lock(&mesh.vertices, @intCast(startVertex), @intCast(count)));
        data.len = count;
        return data;
    }

    pub fn unmapMeshVertices(this: *@This(), Vertex: type, handle: MeshHandle, vertices: []Vertex) void {
        var mesh = this.meshes.items[handle.rawHandle].?;
        c.kinc_g4_vertex_buffer_unlock(&mesh.vertices, @intCast(vertices.len));
    }

    pub fn mapMeshIndices(this: *@This(), handle: MeshHandle, startIndex: usize, count: usize) []u16 {
        var mesh = this.meshes.items[handle.rawHandle].?;
        var data: []u16 = undefined;
        data.ptr = @alignCast(@ptrCast(c.kinc_g4_index_buffer_lock(&mesh.indices, @intCast(startIndex), @intCast(count))));
        data.len = count;
        return data;
    }

    pub fn unmapMeshIndices(this: *@This(), handle: MeshHandle, indices: []u16) void {
        var mesh = this.meshes.items[handle.rawHandle].?;
        c.kinc_g4_index_buffer_unlock(&mesh.indices, @intCast(indices.len));
    }

    pub fn unloadMesh(this: *@This(), handle: MeshHandle) void {
        const mesh = this.meshes.items[handle.rawHandle].?;
        this.meshSpots.append(handle.rawHandle);
        this.meshes.items[handle.rawHandle] = null;
        this._unloadMesh(mesh);
        return mesh;
    }

    pub fn createPipeline(this: *@This(), vertexShaderBinary: []const u8, fragmentShaderBinary: []const u8, args: PipelineArgs) !PipelineHandle {
        // get a free handle
        const rawHandle = blk: {
            if (this.pipelineSpots.items.len > 0) {
                break :blk this.pipelineSpots.pop();
            } else {
                const temp = this.pipelines.items.len;
                _ = try this.pipelines.addOne();
                break :blk temp;
            }
        };
        var pipeline: Pipeline = undefined;
        var vertexShader: c.kinc_g4_shader = undefined;
        var fragmentShader: c.kinc_g4_shader = undefined;

        c.kinc_g4_shader_init(&vertexShader, vertexShaderBinary.ptr, vertexShaderBinary.len, c.KINC_G4_SHADER_TYPE_VERTEX);
        c.kinc_g4_shader_init(&fragmentShader, fragmentShaderBinary.ptr, fragmentShaderBinary.len, c.KINC_G4_SHADER_TYPE_FRAGMENT);

        c.kinc_g4_vertex_structure_init(&pipeline.structure);
        for (args.attributes) |attribute| {
            // The numbers for ZRender match Kinc for a reason
            c.kinc_g4_vertex_structure_add(&pipeline.structure, attribute.name.ptr, @intFromEnum(attribute.type));
        }
        c.kinc_g4_pipeline_init(&pipeline.pipeline);
        pipeline.pipeline.vertex_shader = &vertexShader;
        pipeline.pipeline.fragment_shader = &fragmentShader;
        pipeline.pipeline.input_layout[0] = &pipeline.structure;
        pipeline.pipeline.input_layout[1] = null;
        pipeline.pipeline.depth_mode = c.KINC_G4_COMPARE_GREATER;
        c.kinc_g4_pipeline_compile(&pipeline.pipeline);
        // TODO: custom uniforms
        pipeline.textureUnit = c.kinc_g4_pipeline_get_texture_unit(&pipeline.pipeline, "tex");
        pipeline.transformLocation = c.kinc_g4_pipeline_get_constant_location(&pipeline.pipeline, "transform");

        this.pipelines.items[rawHandle] = pipeline;
        return rawHandle;
    }

    // The rest of the API is basically a bunch of wrappers over Kinc functions
    pub fn run(this: *@This()) void {
        _ = this;
        c.kinc_start();
    }

    fn mouse_enter_window(window: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        const registries = r(data);
        const this = t(registries);
        this.onMouseEnterWindow.publish(OnMouseEnterWindowEventArgs{
            .time = this.lastFrameTime,
            .registries = registries,
        });
    }

    fn mouse_leave_window(window: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        const registries = r(data);
        const this = t(registries);
        this.onMouseLeaveWindow.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
        });
    }

    fn mouse_press(window: c_int, button: c_int, x: c_int, y: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        const registries = r(data);
        const this = t(registries);
        this.onMousePress.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
            .button = @intCast(button),
            .x = @intCast(x),
            .y = @intCast(y),
        });
    }

    fn mouse_release(window: c_int, button: c_int, x: c_int, y: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        const registries = r(data);
        const this = t(registries);
        this.onMouseRelease.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
            .button = @intCast(button),
            .x = @intCast(x),
            .y = @intCast(y),
        });
    }

    fn mouse_move(window: c_int, x: c_int, y: c_int, mov_x: c_int, mov_y: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        const registries = r(data);
        const this = t(registries);
        this.onMouseMove.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
            .x = @intCast(x),
            .y = @intCast(y),
            .deltax = @intCast(mov_x),
            .deltay = @intCast(mov_y),
        });
    }

    fn mouse_scroll(window: c_int, delta: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        const registries = r(data);
        const this = t(registries);
        this.onMouseScroll.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
            .delta = @intCast(delta),
        });
    }

    fn key_down(key: c_int, data: ?*anyopaque) callconv(.C) void {
        const registries = r(data);
        const this = t(registries);
        this.onKeyDown.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
            .key = @enumFromInt(key),
        });
    }
    fn key_up(key: c_int, data: ?*anyopaque) callconv(.C) void {
        const registries = r(data);
        const this = t(registries);
        this.onKeyUp.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
            .key = @enumFromInt(key),
        });
    }

    // What encoding character is supposed to be in is entirely unclear.
    // However, based on minimal testing it appears to be ascii or more likely unicode.
    fn key_press(character: c_uint, data: ?*anyopaque) callconv(.C) void {
        const registries = r(data);
        const this = t(registries);
        this.onType.publish(.{
            .time = this.lastFrameTime,
            .registries = registries,
            .character = @intCast(character),
        });
    }

    fn _loadTexture(this: *@This(), data: []const u8) !Texture {
        var image = c.kinc_image{};
        const memoryLen = c.kinc_image_size_from_encoded_bytes(@constCast(@ptrCast(data.ptr)), data.len, "png");
        const memory: []u8 = try this.allocator.alloc(u8, memoryLen);
        defer this.allocator.free(memory);
        _ = c.kinc_image_init_from_encoded_bytes(&image, memory.ptr, @constCast(@ptrCast(data.ptr)), data.len, "png");
        var texture = c.kinc_g4_texture{};
        c.kinc_g4_texture_init_from_image(&texture, &image);
        return Texture{
            .texture = texture,
        };
    }

    fn _unloadTexture(texture: Texture) void {
        c.kinc_g4_texture_destroy(texture.texture);
    }

    fn _loadMesh(this: *@This(), Vertex: type, vertices: []const Vertex, indices: []const u16, pipeline: *Pipeline) Mesh {
        _ = this;
        var mesh = Mesh{};
        c.kinc_g4_vertex_buffer_init(&mesh.vertices, @intCast(vertices.len), &pipeline.structure, c.KINC_G4_USAGE_STATIC, 0);
        const v: [*]Vertex = @ptrCast(c.kinc_g4_vertex_buffer_lock_all(&mesh.vertices));
        @memcpy(v, vertices);
        c.kinc_g4_vertex_buffer_unlock_all(&mesh.vertices);

        c.kinc_g4_index_buffer_init(&mesh.indices, @intCast(indices.len), c.KINC_G4_INDEX_BUFFER_FORMAT_16BIT, c.KINC_G4_USAGE_STATIC);
        const i: [*]u16 = @alignCast(@ptrCast(c.kinc_g4_index_buffer_lock_all(&mesh.indices)));
        @memcpy(i, indices);
        c.kinc_g4_index_buffer_unlock_all(&mesh.indices);
        return mesh;
    }

    fn _unloadMesh(mesh: Mesh) void {
        c.kinc_g4_vertex_buffer_destroy(mesh.vertices);
        c.kinc_g4_index_buffer_destroy(mesh.indices);
    }

    fn mat4ToKinc(matrix: Mat4) c.kinc_matrix4x4 {
        // TODO: see if this can be done more optimally
        var m = c.kinc_matrix4x4{};
        c.kinc_matrix4x4_set(&m, 0, 0, matrix.m00);
        c.kinc_matrix4x4_set(&m, 0, 1, matrix.m01);
        c.kinc_matrix4x4_set(&m, 0, 2, matrix.m02);
        c.kinc_matrix4x4_set(&m, 0, 3, matrix.m03);

        c.kinc_matrix4x4_set(&m, 1, 0, matrix.m10);
        c.kinc_matrix4x4_set(&m, 1, 1, matrix.m11);
        c.kinc_matrix4x4_set(&m, 1, 2, matrix.m12);
        c.kinc_matrix4x4_set(&m, 1, 3, matrix.m13);

        c.kinc_matrix4x4_set(&m, 2, 0, matrix.m20);
        c.kinc_matrix4x4_set(&m, 2, 1, matrix.m21);
        c.kinc_matrix4x4_set(&m, 2, 2, matrix.m22);
        c.kinc_matrix4x4_set(&m, 2, 3, matrix.m23);

        c.kinc_matrix4x4_set(&m, 3, 0, matrix.m30);
        c.kinc_matrix4x4_set(&m, 3, 1, matrix.m31);
        c.kinc_matrix4x4_set(&m, 3, 2, matrix.m32);
        c.kinc_matrix4x4_set(&m, 3, 3, matrix.m33);
        return m;
    }

    fn update(_data: ?*anyopaque) callconv(.C) void {
        // cast the opaque pointer to what it was previously
        const registries: *zengine.RegistrySet = @alignCast(@ptrCast(_data));
        // get this
        var this = registries.globalRegistry.getRegister(ZRenderSystem).?;

        const realTime = std.time.microTimestamp();

        this.onFrame.publish(.{
            .delta = realTime - this.lastFrameTime,
            .time = realTime,
            .registries = registries,
        });

        // If the update time too far behind, skip ahead. This effectively slows down the game to what the computer can handle.
        if (realTime - this.updateTime > this.maxUpdateLag) {
            this.updateTime = realTime - this.updateDelta;
        }
        // Update until the update time has caught up
        while (realTime - this.updateTime >= this.updateDelta) {
            this.updateTime += this.updateDelta;
            this.onUpdate.publish(.{
                .delta = this.updateDelta,
                .time = this.updateTime,
                .registries = registries,
            });
        }

        c.kinc_g4_begin(0);
        c.kinc_g4_clear(c.KINC_G4_CLEAR_COLOR | c.KINC_G4_CLEAR_DEPTH, 0, 0.0, 0);
        // Draw everything in the global registry
        const view = registries.globalEcsRegistry.basicView(RenderComponent);
        for (view.raw()) |*object| {
            this.drawItem(object);
        }
        // And everything in all of the local registries
        for (registries.localEcsRegistry.items) |*localEcsRegistryOrNone| {
            if (localEcsRegistryOrNone.* == null) continue;
            const localEcsRegistry = &localEcsRegistryOrNone.*.?;
            const localView = localEcsRegistry.basicView(RenderComponent);
            for (localView.raw()) |*object| {
                this.drawItem(object);
            }
        }

        c.kinc_g4_end(0);
        _ = c.kinc_g4_swap_buffers();
    }

    fn drawItem(this: *@This(), object: *RenderComponent) void {
        const pipelineOrNone = &this.pipelines.items[object.pipeline];
        if (pipelineOrNone.* == null) {
            std.debug.print("Invalid pipeline recieved! Skipping object.", .{});
            return;
        }
        const pipeline = &pipelineOrNone.*.?;

        const textureOrNone = &this.textures.items[object.texture];
        if (textureOrNone.* == null) {
            std.debug.print("Invalid texture recieved! Skipping object.", .{});
            return;
        }
        const texture = &textureOrNone.*.?;

        const meshOrNone = &this.meshes.items[object.mesh.rawHandle];
        if (meshOrNone.* == null) {
            std.debug.print("Invalid mesh recieved! Skipping object.", .{});
            return;
        }
        const mesh = &meshOrNone.*.?;

        var transform = mat4ToKinc(object.transform);
        c.kinc_g4_set_pipeline(&pipeline.pipeline);
        c.kinc_g4_set_matrix4(pipeline.transformLocation, &transform);
        c.kinc_g4_set_texture(pipeline.textureUnit, &texture.texture);
        c.kinc_g4_set_vertex_buffer(&mesh.vertices);
        c.kinc_g4_set_index_buffer(&mesh.indices);
        c.kinc_g4_draw_indexed_vertices();
    }

    inline fn r(data: ?*anyopaque) *zengine.RegistrySet {
        if (data == null) @panic("Something is very very very wrong");
        return @as(*zengine.RegistrySet, @alignCast(@ptrCast(data)));
    }

    inline fn t(registries: *zengine.RegistrySet) *@This() {
        return registries.globalRegistry.getRegister(@This()).?;
    }
    // Things that should be considered private members
    pipelines: std.ArrayList(?Pipeline),
    pipelineSpots: std.ArrayList(usize),
    meshes: std.ArrayList(?Mesh),
    meshSpots: std.ArrayList(usize),
    textures: std.ArrayList(?Texture),
    textureSpots: std.ArrayList(TextureHandle),
    // Things that should be considered public members
    allocator: std.mem.Allocator,
    /// Runs for every rendered frame, right before ZRender draws all of the objects.
    onFrame: ecs.Signal(OnFrameEventArgs),
    /// Runs at a constant rate, which is configurable.
    onUpdate: ecs.Signal(OnUpdateEventArgs),
    /// In microseconds. 30 hertz by default.
    updateDelta: i64 = std.time.us_per_s / 30,
    /// The maximum amount of lag between the real time and update time, in microseconds
    maxUpdateLag: i64 = std.time.us_per_s / 10,
    /// The current time in terms of the application, microseconds
    updateTime: i64,
    /// The time when the last frame was rendered
    lastFrameTime: i64,
    onMouseEnterWindow: ecs.Signal(OnMouseEnterWindowEventArgs),
    onMouseLeaveWindow: ecs.Signal(OnMouseLeaveWindowEventArgs),
    onMousePress: ecs.Signal(OnMousePressEventArgs),
    onMouseRelease: ecs.Signal(OnMouseReleaseEventArgs),
    onMouseMove: ecs.Signal(OnMouseMoveEventArgs),
    onMouseScroll: ecs.Signal(OnMouseScrollEventArgs),
    onKeyDown: ecs.Signal(OnKeyDownEventArgs),
    onKeyUp: ecs.Signal(OnKeyUpEventArgs),
    onType: ecs.Signal(OnTypeEventArgs),
};

pub const OnFrameEventArgs = struct {
    // The delta time, in microseconds
    delta: i64,
    // The current time, in microseconds
    time: i64,
    registries: *zengine.RegistrySet,
};

pub const OnUpdateEventArgs = struct {
    // The delta time, in microseconds
    delta: i64,
    // The current time, in microseconds
    time: i64,
    registries: *zengine.RegistrySet,
};

pub const OnMouseEnterWindowEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
};

pub const OnMouseLeaveWindowEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
};

pub const OnMousePressEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    // TODO: enum
    button: u8,
    x: i32,
    y: i32,
};

pub const OnMouseReleaseEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    // TODO: enum
    button: u8,
    x: i32,
    y: i32,
};

pub const OnMouseMoveEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    x: i32,
    y: i32,
    deltax: i32,
    deltay: i32,
};

pub const OnMouseScrollEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    delta: i32,
};

pub const OnKeyDownEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    key: KeyCode,
};

pub const OnKeyUpEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    key: KeyCode,
};

pub const OnTypeEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    /// Note: this character is probably a unicode point, but it might not be.
    character: i32,
};

const Mesh = struct {
    indices: c.kinc_g4_index_buffer = .{},
    vertices: c.kinc_g4_vertex_buffer = .{},
};

const Texture = struct {
    texture: c.kinc_g4_texture = .{},
};

const Pipeline = struct {
    pipeline: c.kinc_g4_pipeline,
    // pipeline has a reference to structure, so it needs to be stored in a place where its lifetime fully encompasses pipeline's.
    structure: c.kinc_g4_vertex_structure,
    textureUnit: c.kinc_g4_texture_unit,
    transformLocation: c.kinc_g4_constant_location,
};

const KeyCode = enum(u32) {
    Unknown = 0,
    Back = 1,
    Cancel = 3,
    Help = 6,
    Backspace = 8,
    Tab = 9,
    Clear = 12,
    Return = 13,
    Shift = 16,
    Control = 17,
    Alt = 18,
    Pause = 19,
    CapsLock = 20,
    //Kana = 21,
    Hangul = 21,
    Eisu = 22,
    Junja = 23,
    Final = 24,
    //Hanja = 25,
    Kanji = 25,
    Escape = 27,
    Convert = 28,
    NonConvert = 29,
    Accept = 30,
    ModeChange = 31,
    Space = 32,
    PageUp = 33,
    PageDown = 34,
    End = 35,
    Home = 36,
    Left = 37,
    Up = 38,
    Right = 39,
    Down = 40,
    Select = 41,
    Print = 42,
    Execute = 43,
    PrintScreen = 44,
    Insert = 45,
    Delete = 46,
    @"0" = 48,
    @"1" = 49,
    @"2" = 50,
    @"3" = 51,
    @"4" = 52,
    @"5" = 53,
    @"6" = 54,
    @"7" = 55,
    @"8" = 56,
    @"9" = 57,
    Colon = 58,
    Semicolon = 59,
    LessThan = 60,
    Equals = 61,
    GreaterThan = 62,
    Questionmark = 63,
    At = 64,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    Win = 91,
    ContextMenu = 93,
    Sleep = 95,
    Numpad0 = 96,
    Numpad1 = 97,
    Numpad2 = 98,
    Numpad3 = 99,
    Numpad4 = 100,
    Numpad5 = 101,
    Numpad6 = 102,
    Numpad7 = 103,
    Numpad8 = 104,
    Numpad9 = 105,
    Multiply = 106,
    Add = 107,
    Separator = 108,
    Subtract = 109,
    Decimal = 110,
    Divide = 111,
    F1 = 112,
    F2 = 113,
    F3 = 114,
    F4 = 115,
    F5 = 116,
    F6 = 117,
    F7 = 118,
    F8 = 119,
    F9 = 120,
    F10 = 121,
    F11 = 122,
    F12 = 123,
    F13 = 124,
    F14 = 125,
    F15 = 126,
    F16 = 127,
    F17 = 128,
    F18 = 129,
    F19 = 130,
    F20 = 131,
    F21 = 132,
    F22 = 133,
    F23 = 134,
    F24 = 135,
    NumLock = 144,
    ScrollLock = 145,
    // TODO: find a better name for these
    WIN_OEM_FJ_JISHO = 146,
    WIN_OEM_FJ_MASSHOU = 147,
    WIN_OEM_FJ_TOUROKU = 148,
    WIN_OEM_FJ_LOYA = 149,
    WIN_OEM_FJ_ROYA = 150,
    Circumflex = 160,
    Exclamation = 161,
    DoubleQuite = 162,
    Hash = 163,
    Dollar = 164,
    Percent = 165,
    Amperstand = 166,
    Underscore = 167,
    OpenParen = 168,
    CloseParen = 169,
    Asterisk = 170,
    Plus = 171,
    Pipe = 172,
    HyphenMinus = 173,
    OpenCurlyBracket = 174,
    CloseCurlyBracket = 175,
    Tilde = 176,
    VolumeMute = 181,
    VolumeDown = 182,
    VolumeUp = 183,
    Comma = 188,
    Period = 190,
    Slash = 191,
    BackQuote = 192,
    OpenBracket = 219,
    BackSlash = 220,
    CloseBracket = 221,
    Quote = 222,
    Meta = 224,
    // TODO: find a better name for these
    ALT_GR = 225,
    WIN_ICO_HELP = 227,
    WIN_ICO_00 = 228,
    WIN_ICO_CLEAR = 230,
    WIN_OEM_RESET = 233,
    WIN_OEM_JUMP = 234,
    WIN_OEM_PA1 = 235,
    WIN_OEM_PA2 = 236,
    WIN_OEM_PA3 = 237,
    WIN_OEM_WSCTRL = 238,
    WIN_OEM_CUSEL = 239,
    WIN_OEM_ATTN = 240,
    WIN_OEM_FINISH = 241,
    WIN_OEM_COPY = 242,
    WIN_OEM_AUTO = 243,
    WIN_OEM_ENLW = 244,
    WIN_OEM_BACK_TAB = 245,
    ATTN = 246,
    CRSEL = 247,
    EXSEL = 248,
    EREOF = 249,
    Play = 250,
    Zoom = 251,
    PA1 = 253,
    WIN_OEM_CLEAR = 254,
};
