const std = @import("std");
const builtin = @import("builtin");
const kinc = @import("Kinc.zig/build.zig");

pub const Shader = struct {
    /// Source path relative to your build.zig. Shader code must be in GLSL and the file name must end in 'vert.glsl' or 'frag.glsl'
    sourcePath: []const u8,
    /// Destination path relative to your build.zig
    destPath: []const u8,
};

pub const ZrenderOptions = struct {
    KmakeOptions: kinc.KmakeOptions,
    shaders: []const Shader,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn link(comptime modulePath: []const u8, b: *std.Build, zengine: *std.Build.Module, ecs: *std.Build.Module, options: ZrenderOptions) !*std.Build.Step.Compile {
    const kincModulePath = modulePath ++ "/Kinc.zig/Kinc";
    const zrender = b.addStaticLibrary(.{
        .name = "zrender",
        .root_source_file = .{ .path = modulePath ++ "/src/zrender.zig" },
        // TODO: take these as parameters
        .target = options.target,
        .optimize = options.optimize,
    });
    zrender.root_module.addImport("zengine", zengine);
    zrender.root_module.addImport("ecs", ecs);

    try kinc.link(kincModulePath, zrender, options.KmakeOptions);
    for (options.shaders) |shader| {
        try kinc.compileShader(kincModulePath, zrender, shader.sourcePath, shader.destPath, options.KmakeOptions);
    }
    return zrender;
}
