const std = @import("std");
const gl = @import("../ZRenderGL41.zig").gl;
const sdl = @import("sdl");
const impl = @import("../ZRenderImpl.zig");
const GL41Mesh = @import("mesh.zig").GL41Mesh;
const GL41ShaderProgram = @import("shader.zig").GL41ShaderProgram;

pub const GL41RenderQueueItem = union(enum) {
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

pub const GL41RenderQueue = struct {
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
    pub fn run(this: *@This(), window: anytype) void {
        for(this.items.items) |item| {
            switch (item) {
                .clearToColor => |color| {
                    gl.clearColor(@as(f32, @floatFromInt(color.r)) / 256.0, @as(f32,@floatFromInt(color.g)) / 256.0, @as(f32, @floatFromInt(color.b)) / 256.0, @as(f32, @floatFromInt(color.a)) / 256.0);
                    gl.clear(gl.COLOR_BUFFER_BIT);
                },
                .presentFramebuffer => |vsync| {
                    window.presentFramebuffer(vsync);
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