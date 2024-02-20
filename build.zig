const std = @import("std");
const builtin = @import("builtin");
const kinc = @import("Kinc.zig/build.zig");

pub fn link(comptime modulePath: []const u8, c: *std.Build.Step.Compile, zengine: *std.Build.Module, ecs: *std.Build.Module) !void {
    // TODO: take in options as parameters
    const options = kinc.KmakeOptions{
        .platform = .guess,
    };
    const kincModulePath = modulePath ++ "/Kinc.zig/Kinc";
    const zrender = c.root_module.owner.addStaticLibrary(.{
        .name = "zrender",
        .root_source_file = .{ .path = modulePath ++ "/src/zrender.zig" },
        .target = c.root_module.resolved_target.?,
        .optimize = c.root_module.optimize.?,
    });
    zrender.root_module.addImport("zengine", zengine);
    zrender.root_module.addImport("ecs", ecs);

    try kinc.link(kincModulePath, zrender, options);
    try kinc.compileShader(kincModulePath, zrender, modulePath ++ "/src/shaders/shader.frag.glsl", modulePath ++ "/src/shaderBin/shader.frag", options);
    try kinc.compileShader(kincModulePath, zrender, modulePath ++ "/src/shaders/shader.vert.glsl", modulePath ++ "/src/shaderBin/shader.vert", options);

    c.root_module.addImport("zrender", &zrender.root_module);
}
