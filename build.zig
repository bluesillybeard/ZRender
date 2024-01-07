const std = @import("std");
const sdl2sdk = @import("SDL.zig/build.zig");

// name, path
const examples = [_][2][]const u8 {
    [2][]const u8 {"simple", "examples/0_simple.zig"},
    [2][]const u8 {"triangle", "examples/1_triangle.zig"},
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //ZRender depends on SDL.zig. As long as it's added as a module, it should work.
    const sdl2 = sdl2sdk.init(b, null);

    //get zig-interface
    const interfaceModule = b.addModule("interface", .{
        .source_file = .{.path="zig-interface/src/interface.zig"},
    });

    // ZRender is a source library.
    // It is meant to be directly incorperated into a projects source code,
    // using a zig module, like so.
    const zrender = b.addModule("zrender", .{
        .source_file = .{.path="src/ZRender.zig"},
        .dependencies = &[_]std.Build.ModuleDependency{
            .{.name = "sdl", .module = sdl2.getWrapperModule()},
            .{.name = "interface", .module = interfaceModule}},
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

    // build the vscode step
    var ideStep = b.step("vscode", "Generate the vscode launch.json and tasks.json");
    const ideFiles = try generateVSCodeFiles(b.allocator);
    var write = b.addWriteFiles();
    write.addBytesToSource(ideFiles.launch, ".vscode/launch.json");
    write.addBytesToSource(ideFiles.tasks, ".vscode/tasks.json");
    ideStep.dependOn(&write.step);

}

pub fn linkLibs(exe: *std.Build.CompileStep, target: std.zig.CrossTarget, sdl2: *sdl2sdk) void {
    _ = target;
    // I thought linking with SDL would be easy, but apparently it's fairly complex to do it correctly with cross-compilation support.
    // But, this wrapper does it for me so yay
    sdl2.link(exe, .dynamic);
}

pub fn generateVSCodeFiles(allocator: std.mem.Allocator) anyerror!struct {launch: []const u8, tasks: []const u8} {
    // Editing vscode launch.json and tasks.json is normally OK,
    // But with all these examples it is a giant pain,
    // So the above list of examples will be used to generate the launch.json and tasks.json
    // for the project, saving me quite a bit of work.

    // TODO: It might be worth generating tasks/launch configs for other IDEs as well,
    // it depends on if anyone other than me actually uses this project.

    // For the sake of simplicity, just allocate a massive buffer that's larger than the file could ever reasonably be.
    var launchBuffer = try allocator.alloc(u8, 1024 + 1024 * examples.len);
    var tasksBuffer = try allocator.alloc(u8, 1024 + 1024 * examples.len);
    var launchStream = std.io.fixedBufferStream(launchBuffer);
    var tasksStream = std.io.fixedBufferStream(tasksBuffer);
    var launch = launchStream.writer();
    var tasks = tasksStream.writer();
    _ = try launch.write(
        \\ {
        \\     "version": "0.2.0",
        \\     "configurations": [
        \\
    );
    _ = try tasks.write(
        \\ {
        \\     "version": "2.0.0",
        \\     "tasks": [
        \\         {
        \\             "label": "build",
        \\             "type": "shell",
        \\             "command": "zig build install",
        \\             "problemMatcher": [],
        \\             "group": {
        \\                 "kind": "build",
        \\                 "isDefault": true
        \\             }
        \\         },
        \\
    );
    inline for(examples) |example| {
        const name = example[0];
        _ = try launch.print(
        \\         {{
        \\             "type": "lldb",
        \\             "request": "launch",
        \\             "name": "Launch {s}  example (debug)",
        \\             "preLaunchTask": "build{s}",
        \\             "program": "${{workspaceFolder}}/zig-out/bin/{s}",
        \\             "args": [],
        \\             "cwd": "${{workspaceFolder}}"
        \\         }},
        \\
        , .{name, name, name});
        _ = try tasks.print(
        \\         {{
        \\         "label": "build{s}",
        \\             "type": "shell",
        \\             "command": "zig build {s}",
        \\             "problemMatcher": [],
        \\             "group": {{
        \\                 "kind": "build",
        \\                 "isDefault": false
        \\             }}
        \\         }},
        \\
        , .{name, name});
    }
    _ = try launch.write("    ]\n}");
    _ = try tasks.write("    ]\n}");
    const launchStr = launchBuffer[0..launch.context.pos];
    const tasksStr = tasksBuffer[0..tasks.context.pos];
    return .{.launch = launchStr, .tasks = tasksStr};
}
