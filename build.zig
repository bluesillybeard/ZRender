const std = @import("std");
const sdl2sdk = @import("SDL.zig/build.zig");

const examples = [_][2][]const u8 {
    [2][]const u8{"simple", "examples/Simple.zig"},
    [2][]const u8 {"windows", "examples/Windows.zig"},
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //ZRender depends on SDL.zig. As long as it's added as a module, it should work.
    const sdl2 = sdl2sdk.init(b, null);

    // ZRender is a source library.
    // It is meant to be directly incorperated into a projects source code,
    // using a zig module, like so.
    const zrender = b.addModule("zrender", .{
        .source_file = .{.path="src/ZRender.zig"},
        .dependencies = &[_]std.Build.ModuleDependency{.{.name = "sdl", .module = sdl2.getWrapperModule()}},
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
        linkLibs(exe, target, sdl2);

        // add to the install step so it builds all of the examples by default
        b.installArtifact(exe);

        // also a step to build this specific example
        var step = b.step(name, "build the " ++ name ++ " example");

        var artifact = b.addInstallArtifact(exe, .{});
        step.dependOn(&artifact.step);
    }
}

pub fn linkLibs(exe: *std.Build.CompileStep, target: std.zig.CrossTarget, sdl2: *sdl2sdk) void {
    _ = target;
    exe.linkLibC();
    // I thought linking with SDL would be easy, but apparently it's fairly complex to do it correctly with cross-compilation support.
    // But, this wrapper does it for me so yay
    sdl2.link(exe, .dynamic);
}