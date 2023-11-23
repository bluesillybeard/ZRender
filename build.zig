const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ZRender is a source library.
    // It is meant to be directly incorperated into a projects source code,
    // using a zig module.
    const zrender = b.addModule("zrender", .{
        .source_file = .{.path="src/ZRender.zig"} 
    });

    // the simple example
    const exe = b.addExecutable(.{
        .name = "simple",
        .root_source_file = .{
            .path = "src/Simple.zig"
            },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("zrender", zrender);
    linkLibs(exe, target);

    b.installArtifact(exe);
}

pub fn linkLibs(exe: *std.Build.CompileStep, target: std.zig.CrossTarget) void {
    exe.linkLibC();
    switch (target.getOsTag()) {
        .linux => {
            exe.linkSystemLibrary("glfw");
            exe.linkSystemLibrary("GL");
        },
        .windows => {
            // TODO: test in a windows VM
            // TODO: figure out how to link glfw as a system library with cross-os compilation
            exe.linkSystemLibrary("glfw");
            exe.linkSystemLibrary("opengl32");
        },
        else => {
            @panic("Unsupported OS - only Linux and Windows are supported for now");
        }
    }
}