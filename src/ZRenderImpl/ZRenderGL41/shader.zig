const std = @import("std");
const gl = @import("../ZRenderGL41.zig").gl;
const impl = @import("../ZRenderImpl.zig");

pub const GL41ShaderProgram = union(enum) {
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

    pub fn setUniforms(self: *GL41ShaderProgram, uniforms: []impl.DrawUniform) void {
        for(uniforms, 0..) |uniform, i| {
            const location: gl.GLint = @intCast(i);
            switch (uniform) {
                .none => {},
                .float => |v| gl.programUniform1f(self.loaded.program, location, v),
                .int => |v| gl.programUniform1i(self.loaded.program, location, v),
                .uint => |v| gl.programUniform1ui(self.loaded.program, location, v),
                .vec2 => |v| gl.programUniform2f(self.loaded.program, location, v.x, v.y),
                .vec2i => |v| gl.programUniform2i(self.loaded.program, location, v.x, v.y),
                .vec2u => |v| gl.programUniform2ui(self.loaded.program, location, v.x, v.y),
                .vec3 => |v| gl.programUniform3f(self.loaded.program, location, v.x, v.y, v.z),
                .vec3i => |v| gl.programUniform3i(self.loaded.program, location, v.x, v.y, v.z),
                .vec3u => |v| gl.programUniform3ui(self.loaded.program, location, v.x, v.y, v.z),
                .vec4 => |v| gl.programUniform4f(self.loaded.program, location, v.x, v.y, v.z, v.w),
                .vec4i => |v| gl.programUniform4i(self.loaded.program, location, v.x, v.y, v.z, v.w),
                .vec4u => |v| gl.programUniform4ui(self.loaded.program, location, v.x, v.y, v.z, v.w),
            }
        }
    }
};