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
});

pub const RenderComponent = struct {
    mesh: Mesh,
    texture: Texture,
    transform: Mat4
};

pub const Vertex = extern struct {
    x: f32, y: f32, z: f32,
    texY: f32, texX: f32,
    /// Red is the least significant byte, Alpha is the most significant
    color: u32,
    /// 0 -> texture, 1 -> color
    blend: f32,
};

pub const Mesh = struct {
    c.kinc_g4_index_buffer,
    c.kinc_g4_vertex_buffer,
};

pub const Texture = struct {
    //TODO
};

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
            .pipeline = .{},
            .vertices = .{},
            .indices = .{},
            .texture = .{},
            .textureUnit = .{},
            .transformLocation = .{},
            .allocator = heapAllocator,
        };
    }

    pub fn systemInitGlobal(this: *@This(), registries: *zengine.RegistrySet) !void {
        _ = registries;
        _ = this;
    }

    pub fn systemDeinitGlobal(this: *@This(), registries: *zengine.RegistrySet) void {
        _ = registries;
        _ = this;
    }

    pub fn deinit(this: *@This()) void {
        _ = this;
    }

    pub fn initZRender(this: *@This(), registries: *zengine.RegistrySet) !void {
        var vertex_shader: c.kinc_g4_shader_t = .{};
        var fragment_shader: c.kinc_g4_shader_t = .{};
        _ = c.kinc_init("Shader", 1024, 768, null, null);
        c.kinc_set_update_callback(&update, registries);
        // In the original test, the shaders are loaded in a separate function
        // and the "allocator" is a buffer allocator to a chunk of memory.
        // Instead, the @embedFile builtin is used, which eliminates the need to allocate memory or load a file at runtime.
        const vertexShaderCode = @embedFile("shaderBin/shader.vert");
        c.kinc_g4_shader_init(&vertex_shader, vertexShaderCode.ptr, vertexShaderCode.len, c.KINC_G4_SHADER_TYPE_VERTEX);
        const fragmentShaderCode = @embedFile("shaderBin/shader.frag");
        c.kinc_g4_shader_init(&fragment_shader, fragmentShaderCode.ptr, fragmentShaderCode.len, c.KINC_G4_SHADER_TYPE_FRAGMENT);


        var structure: c.kinc_g4_vertex_structure_t = .{};
        c.kinc_g4_vertex_structure_init(&structure);
        c.kinc_g4_vertex_structure_add(&structure, "pos", c.KINC_G4_VERTEX_DATA_F32_3X);
        c.kinc_g4_vertex_structure_add(&structure, "texCoord", c.KINC_G4_VERTEX_DATA_F32_2X);
        c.kinc_g4_vertex_structure_add(&structure, "color", c.KINC_G4_VERTEX_DATA_U8_4X_NORMALIZED);
        c.kinc_g4_vertex_structure_add(&structure, "blend", c.KINC_G4_VERTEX_DATA_F32_1X);
        c.kinc_g4_pipeline_init(&this.pipeline);
        this.pipeline.vertex_shader = &vertex_shader;
        this.pipeline.fragment_shader = &fragment_shader;
        this.pipeline.input_layout[0] = &structure;
        this.pipeline.input_layout[1] = null;
        c.kinc_g4_pipeline_compile(&this.pipeline);
        c.kinc_g4_vertex_buffer_init(&this.vertices, 3, &structure, c.KINC_G4_USAGE_STATIC, 0);
        {
            const v: *[3]Vertex = @ptrCast(c.kinc_g4_vertex_buffer_lock_all(&this.vertices));
            v.* = [3]Vertex {
                Vertex{.x = -1, .y = -1, .z = 0.5, .texX = 0, .texY = 0, .color = 0xFFFFFF00, .blend = 1},
                Vertex{.x =  1, .y = -1, .z = 0.5, .texX = 1, .texY = 0, .color = 0xFF00FFFF, .blend = 1},
                Vertex{.x = -1, .y =  1, .z = 0.5, .texX = 0, .texY = 1, .color = 0xFFFF00FF, .blend = 0},
            };
            c.kinc_g4_vertex_buffer_unlock_all(&this.vertices);
        }
        c.kinc_g4_index_buffer_init(&this.indices, 3, c.KINC_G4_INDEX_BUFFER_FORMAT_16BIT, c.KINC_G4_USAGE_STATIC);
        {
            const i: *[3]u16 = @alignCast(@ptrCast(c.kinc_g4_index_buffer_lock_all(&this.indices)));
            i.* = [3]u16{0, 1, 2};
            c.kinc_g4_index_buffer_unlock_all(&this.indices);
        }
        var image = c.kinc_image{};
        const memory: []u8 = try this.allocator.alloc(u8, 250 * 250 * 4);
        const data = @embedFile("parrot.png");
        //_ = c.kinc_image_init_from_file(&image, @ptrCast(&data), "parrot.png");
        _ = c.kinc_image_init_from_encoded_bytes(&image, memory.ptr, @constCast(@ptrCast(data.ptr)), data.len, "png");
        c.kinc_g4_texture_init_from_image(&this.texture, &image);
        this.textureUnit = c.kinc_g4_pipeline_get_texture_unit(&this.pipeline, "tex");
        this.transformLocation = c.kinc_g4_pipeline_get_constant_location(&this.pipeline, "transform");
    }

    pub fn run(this: *@This()) void {
        _ = this;
        c.kinc_start();
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

        c.kinc_g4_begin(0);
        c.kinc_g4_clear(c.KINC_G4_CLEAR_COLOR, 0, 0.0, 0);
        c.kinc_g4_set_pipeline(&this.pipeline);
        var identity = mat4ToKinc(Mat4.identity);
        c.kinc_g4_set_matrix4(this.transformLocation, &identity);
        c.kinc_g4_set_texture(this.textureUnit, &this.texture);
        c.kinc_g4_set_vertex_buffer(&this.vertices);
        c.kinc_g4_set_index_buffer(&this.indices);
        c.kinc_g4_set_texture(this.textureUnit, &this.texture);
        c.kinc_g4_draw_indexed_vertices();
        c.kinc_g4_end(0);
        _ = c.kinc_g4_swap_buffers();
    }
    pipeline: c.kinc_g4_pipeline,
    vertices: c.kinc_g4_vertex_buffer,
    indices: c.kinc_g4_index_buffer,
    texture: c.kinc_g4_texture,
    textureUnit: c.kinc_g4_texture_unit,
    transformLocation: c.kinc_g4_constant_location,
    allocator: std.mem.Allocator,
};

