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

pub const RenderComponent = struct {
    mesh: MeshHandle,
    texture: TextureHandle,
    transform: Mat4
};

pub const Vertex = extern struct {
    x: f32, y: f32, z: f32,
    texX: f32, texY: f32,
    /// Red is the least significant byte, Alpha is the most significant
    color: u32,
    /// 0 -> texture, 1 -> color
    blend: f32,
};

pub const MeshHandle = usize;

pub const TextureHandle = usize;

pub const Mat4 = extern struct {
    m00: f32, m01: f32, m02: f32, m03: f32,
    m10: f32, m11: f32, m12: f32, m13: f32,
    m20: f32, m21: f32, m22: f32, m23: f32,
    m30: f32, m31: f32, m32: f32, m33: f32,

    pub const identity = Mat4{
        .m00 = 1, .m01 = 0, .m02 = 0, .m03 = 0,
        .m10 = 0, .m11 = 1, .m12 = 0, .m13 = 0,
        .m20 = 0, .m21 = 0, .m22 = 1, .m23 = 0,
        .m30 = 0, .m31 = 0, .m32 = 0, .m33 = 1,
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
            .structure = .{},
            .pipeline = .{},
            .meshes = std.ArrayList(?Mesh).init(heapAllocator),
            .meshSpots = std.ArrayList(MeshHandle).init(heapAllocator),
            .textures = std.ArrayList(?Texture).init(heapAllocator),
            .textureSpots = std.ArrayList(TextureHandle).init(heapAllocator),
            .textureUnit = .{},
            .transformLocation = .{},
            .allocator = heapAllocator,
            .onFrame = ecs.Signal(OnFrameEventArgs).init(heapAllocator),
            .onUpdate = ecs.Signal(OnUpdateEventArgs).init(heapAllocator),
            .updateTime = std.time.microTimestamp(),
            .lastFrameTime = std.time.microTimestamp(),
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
        this.meshes.deinit();
        this.meshSpots.deinit();
        this.textures.deinit();
        this.textureSpots.deinit();
        this.onFrame.deinit();
        this.onUpdate.deinit();
    }

    fn initZRender(this: *@This(), registries: *zengine.RegistrySet) !void {
        var vertex_shader: c.kinc_g4_shader_t = .{};
        var fragment_shader: c.kinc_g4_shader_t = .{};
        _ = c.kinc_init("Shader", 1024, 768, null, null);
        c.kinc_set_update_callback(&update, registries);
        const vertexShaderCode = @embedFile("shaderBin/shader.vert");
        c.kinc_g4_shader_init(&vertex_shader, vertexShaderCode.ptr, vertexShaderCode.len, c.KINC_G4_SHADER_TYPE_VERTEX);
        const fragmentShaderCode = @embedFile("shaderBin/shader.frag");
        c.kinc_g4_shader_init(&fragment_shader, fragmentShaderCode.ptr, fragmentShaderCode.len, c.KINC_G4_SHADER_TYPE_FRAGMENT);

        c.kinc_g4_vertex_structure_init(&this.structure);
        c.kinc_g4_vertex_structure_add(&this.structure, "pos", c.KINC_G4_VERTEX_DATA_F32_3X);
        c.kinc_g4_vertex_structure_add(&this.structure, "texCoord", c.KINC_G4_VERTEX_DATA_F32_2X);
        c.kinc_g4_vertex_structure_add(&this.structure, "color", c.KINC_G4_VERTEX_DATA_U8_4X_NORMALIZED);
        c.kinc_g4_vertex_structure_add(&this.structure, "blend", c.KINC_G4_VERTEX_DATA_F32_1X);
        c.kinc_g4_pipeline_init(&this.pipeline);
        this.pipeline.vertex_shader = &vertex_shader;
        this.pipeline.fragment_shader = &fragment_shader;
        this.pipeline.input_layout[0] = &this.structure;
        this.pipeline.input_layout[1] = null;
        c.kinc_g4_pipeline_compile(&this.pipeline);
        this.textureUnit = c.kinc_g4_pipeline_get_texture_unit(&this.pipeline, "tex");
        this.transformLocation = c.kinc_g4_pipeline_get_constant_location(&this.pipeline, "transform");

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
            if(this.textureSpots.items.len > 0){
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

    pub fn loadMesh(this: *@This(), vertices: []const Vertex, indices: []const u16) !MeshHandle {
        const mesh = this._loadMesh(vertices, indices);
        // get a free handle
        const handle = blk: {
            if(this.meshes.items.len > 0){
                break :blk this.meshSpots.pop();
            } else {
                const temp = this.textures.items.len;
                _ = try this.meshes.addOne();
                break :blk temp;
            }
        };
        this.meshes.items[handle] = mesh;
        return handle;
    }

    // The rest of the API is basically a bunch of wrappers over Kinc functions
    pub fn run(this: *@This()) void {
        _ = this;
        c.kinc_start();
    }

    fn mouse_enter_window(window: c_int, data: ?*anyopaque) callconv(.C) void {
        const registries = r(data);
        const this = t(registries);
        _ = this;
        // my lsp is having a ceisure rn

        _ = window;
        // TODO
    }

    fn mouse_leave_window(window: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        _ = data;
        // TODO
    }

    fn mouse_press(window: c_int, button: c_int, x: c_int, y: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        _ = button;
        _ = x;
        _ = y;
        _ = data;
        // TODO
    }

    fn mouse_release(window: c_int, button: c_int, x: c_int, y: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        _ = button;
        _ = x;
        _ = y;
        _ = data;
        // TODO
    }
    
    fn mouse_move(window: c_int, x: c_int, y: c_int, mov_x: c_int, mov_y: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        _ = x;
        _ = y;
        _ = mov_x;
        _ = mov_y;
        _ = data;
        //TODO
    }

    fn mouse_scroll(window: c_int, delta: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = window;
        _ = delta;
        _ = data;
        // TODO
    }

    // Hmm, strange that key down merges inputs from all windows.
    // TODO: When adding multiwindowing to ZRender,
    // see if there is a way to differentiate keystrokes between different windows.
    // If not, look into making a PR into Kinc to add it.
    fn key_down(key: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = key;
        _ = data;
        // TODO
    }
    fn key_up(key: c_int, data: ?*anyopaque) callconv(.C) void {
        _ = key;
        _ = data;
        // TODO
    }
    
    // What encoding character is supposed to be in is entirely unclear.
    // However, based on minimal testing it appears to be ascii or more likely unicode.
    fn key_press(character: c_uint, data: ?*anyopaque) callconv(.C) void {
        _ = data;
        _ = character;
        // TODO
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

    fn _loadMesh(this: *@This(), vertices: []const Vertex, indices: []const u16) Mesh {
        var mesh = Mesh{};
        c.kinc_g4_vertex_buffer_init(&mesh.vertices, @intCast(vertices.len), &this.structure, c.KINC_G4_USAGE_STATIC, 0);
        const v: [*]Vertex = @ptrCast(c.kinc_g4_vertex_buffer_lock_all(&mesh.vertices));
        @memcpy(v, vertices);
        c.kinc_g4_vertex_buffer_unlock_all(&mesh.vertices);

        c.kinc_g4_index_buffer_init(&mesh.indices, @intCast(indices.len), c.KINC_G4_INDEX_BUFFER_FORMAT_16BIT, c.KINC_G4_USAGE_STATIC);
        const i: [*]u16 = @alignCast(@ptrCast(c.kinc_g4_index_buffer_lock_all(&mesh.indices)));
        @memcpy(i, indices);
        c.kinc_g4_index_buffer_unlock_all(&mesh.indices);
        return mesh;
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
        if(realTime - this.updateTime > this.maxUpdateLag) {
            this.updateTime = realTime - this.updateDelta;
        }
        // Update until the update time has caught up
        while(realTime - this.updateTime >= this.updateDelta) {
            this.updateTime += this.updateDelta;
            this.onUpdate.publish(.{
                .delta = this.updateDelta,
                .time = this.updateTime,
                .registries = registries,
            });
        }

        c.kinc_g4_begin(0);
        c.kinc_g4_clear(c.KINC_G4_CLEAR_COLOR | c.KINC_G4_CLEAR_DEPTH, 0, 0.0, 0);
        c.kinc_g4_set_pipeline(&this.pipeline);
        // Draw everything in the global registry
        const view = registries.globalEcsRegistry.basicView(RenderComponent);
        for(view.raw()) |object| {
            this.drawItem(object);
        }
        // And everything in all of the local registries
        for(registries.localEcsRegistry.items) |*localEcsRegistryOrNone| {
            if(localEcsRegistryOrNone.* == null) continue;
            const localEcsRegistry = &localEcsRegistryOrNone.*.?;
            const localView = localEcsRegistry.basicView(RenderComponent);
            for(localView.raw()) |object| {
                this.drawItem(object);
            }
        }
        
        c.kinc_g4_end(0);
        _ = c.kinc_g4_swap_buffers();
    }

    fn drawItem(this: *@This(), object: RenderComponent) void {
        var transform = mat4ToKinc(object.transform);
        c.kinc_g4_set_matrix4(this.transformLocation, &transform);
        const textureOrNone = &this.textures.items[object.texture];
        if(textureOrNone.* == null){
            std.debug.print("Invalid texture recieved! Skipping object.", .{});
            return;
        }
        const texture = &textureOrNone.*.?;
        c.kinc_g4_set_texture(this.textureUnit, &texture.texture);
        const meshOrNone = &this.meshes.items[object.mesh];
        if(meshOrNone.* == null){
            std.debug.print("Invalid mesh recieved! Skipping object.", .{});
            return;
        }
        const mesh = &meshOrNone.*.?;
        c.kinc_g4_set_vertex_buffer(&mesh.vertices);
        c.kinc_g4_set_index_buffer(&mesh.indices);
        c.kinc_g4_draw_indexed_vertices();
    }


    inline fn r(data: ?*anyopaque) *zengine.RegistrySet {
        if(data == null) @panic("Something is very very very wrong");
        return @as(*zengine.RegistrySet, @alignCast(@ptrCast(data)));
    }

    inline fn t(registries: *zengine.RegistrySet) *@This() {
        return registries.globalRegistry.getRegister(@This()).?;
    }
    // Things that should be considered private members
    // pipeline has a reference to structure, so this needs to be stored in a place where its lifetime fully encompasses pipeline's.
    structure: c.kinc_g4_vertex_structure,
    pipeline: c.kinc_g4_pipeline,
    meshes: std.ArrayList(?Mesh),
    meshSpots: std.ArrayList(MeshHandle),
    textures: std.ArrayList(?Texture),
    textureSpots: std.ArrayList(TextureHandle),
    textureUnit: c.kinc_g4_texture_unit,
    transformLocation: c.kinc_g4_constant_location,
    // Things that should be considered public members
    allocator: std.mem.Allocator,
    /// Runs for every rendered frame, right before ZRender draws all of the objects.
    onFrame: ecs.Signal(OnFrameEventArgs),
    /// Runs at a constant rate, which is configurable.
    onUpdate: ecs.Signal(OnUpdateEventArgs),
    /// In microseconds. 60 hertz by default.
    updateDelta: i64 = std.time.us_per_s / 60,
    /// The maximum amount of lag between the real time and update time, in microseconds
    maxUpdateLag: i64 = std.time.us_per_s / 30,
    /// The current time in terms of the application, microseconds
    updateTime: i64,
    /// The time when the last frame was rendered
    lastFrameTime: i64,
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

pub const MouseEnterWindowEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
};

pub const MouseExitWindowEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
};

pub const MousePressEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    // TODO: enum
    button: u8,
    x: i32,
    y: i32,
};

pub const MouseReleaseEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    // TODO: enum
    button: u8,
    x: i32,
    y: i32,
};

pub const MouseMoveEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    x: i32,
    y: i32,
    deltax: i32,
    deltay: i32,
};

pub const MouseScrollEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    delta: i32,
};

pub const KeyDownEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    // TODO: enum
    key: i32,
};

pub const KeyUpEventArgs = struct {
    time: i64,
    registries: *zengine.RegistrySet,
    // TODO: enum
    key: i32,
};

pub const TypeEventArgs = struct {
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
