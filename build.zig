const std = @import("std");

const examples = [_][2][]const u8 {
    [2][]const u8{"simple", "examples/Simple.zig"},
    [2][]const u8 {"windows", "examples/Windows.zig"},
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ZRender is a source library.
    // It is meant to be directly incorperated into a projects source code,
    // using a zig module.
    const zrender = b.addModule("zrender", .{
        .source_file = .{.path="src/ZRender.zig"} 
    });

    inline for(examples) |example| {
        const name = example[0];
        const path = example[1];
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = .{.path = path},
            .target = target,
            .optimize = optimize,
        });
        exe.out_filename = name;
        exe.addModule("zrender", zrender);
        linkLibs(exe, target);

        // add to the install step so it builds all of the examples by default
        b.installArtifact(exe);

        // also a step to build this specific example
        var step = b.step(name, "build the " ++ name ++ " example");

        var artifact = b.addInstallArtifact(exe, .{});
        step.dependOn(&artifact.step);
    }
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