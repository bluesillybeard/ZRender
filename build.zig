const std = @import("std");
const builtin = @import("builtin");
const kinc = @import("Kinc.zig/build.zig");

pub fn link(comptime modulePath: []const u8, c: *std.Build.Step.Compile) !void {
    // TODO: take in options as parameters
    const options = kinc.KmakeOptions{
        .platform = .guess,
    };
    const realModulePath = modulePath ++ "/Kinc.zig/Kinc";
    try kinc.link(realModulePath, c, options);
    try kinc.compileShader(realModulePath, c, modulePath ++ "/src/shaders/shader.frag.glsl", modulePath ++ "src/shaderBin/shader.frag", options);
    try kinc.compileShader(realModulePath, c, modulePath ++ "/src/shaders/shader.vert.glsl", modulePath ++ "src/shaderBin/shader.vert", options);

    const zrender = c.root_module.owner.createModule(.{
        .root_source_file = .{.path = modulePath ++ "/src/zrender.zig"},
        .target = c.root_module.resolved_target,
        .optimize = c.root_module.optimize,
    });
    c.root_module.addImport("zrender", zrender);
}
