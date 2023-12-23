const std = @import("std");
const gl = @import("../ZRenderGL41.zig").gl;
const impl = @import("../ZRenderImpl.zig");


pub const GL41Mesh = union(enum) {
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
        usageHint: impl.MeshUsageHint,
        /// What type of mesh this is
        type: impl.MeshType,
        /// The mesh attributes, this memory matches the lifetime of the OpenGL object.
        attributes: []const impl.MeshAttribute,
    },
    initialized: struct {
        type: impl.MeshType,
        attributes: []const impl.MeshAttribute,
        vertexBuffer: []const u8,
        indices: []const u32,
        usageHint: impl.MeshUsageHint,
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

    pub fn subVertexBuffer(self: *GL41Mesh, start: usize, vertexBuffer: []const u8) void {
        gl.bindBuffer(gl.ARRAY_BUFFER, self.loaded.vertexBufferObject);
        gl.bufferSubData(gl.ARRAY_BUFFER, start, @intCast(vertexBuffer.len), vertexBuffer.ptr);
    }

    pub fn subIndices(self: *GL41Mesh, start: usize, indices: []const u32) void {
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.loaded.indexBufferObject);
        gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER, start, @intCast(indices.len * @sizeOf(u32)), indices.ptr);
    }
};

fn attribSize(attrib: impl.MeshAttribute) usize {
    return switch (attrib) {
        .byte => @sizeOf(gl.GLubyte),
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

fn attribIsInt(attrib: impl.MeshAttribute) bool {
    return switch (attrib) {
        .byte => true,
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

fn attribToGLenum(attrib: impl.MeshAttribute) gl.GLenum {
    return switch (attrib) {
        .byte => gl.UNSIGNED_BYTE,
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

fn attribElements(attrib: impl.MeshAttribute) gl.GLint {
    return switch (attrib) {
        .byte => 1,
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
