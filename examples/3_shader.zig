// This example demonstrates usage of every shader. EVERY. shader.
// Each shader is demonstrated in its own window.
// Closing one window will not close the others, so close the ones you aren't interested in.

const std = @import("std");
const ZRender = @import("zrender");
const alloc = std.heap.GeneralPurposeAllocator(.{});

const WindowData = struct {
    /// A handle to the actual window.
    /// This is owned.
    window: ZRender.WindowHandle,
    /// The object that when drawn will demonstrate a shader.
    /// this is owned, so even if the mesh is identical to another, it is a separate object and must be freed separately.
    object: ZRender.DrawObject,
};

pub fn main() !void {
    var allocatorObj = alloc{};
    defer _ = allocatorObj.deinit();
    const allocator = allocatorObj.allocator();
    // Create instance with default options
    var instance = try ZRender.initInstance(.{.allocator = allocator});
    defer instance.deinit();

    // Create a window for every shader
    var windows = std.ArrayList(WindowData).init(allocator);
    defer windows.deinit();

    try makeWindows(instance, &windows);
    // A mesh for the SolidColor shader that draws an outline around the window.
    const inset = 0.05;

    const outlineMesh = try instance.static_createMesh(f32,
        &[_]f32{
            // Each outer corner (indices 0, 1, 2, 3)
            1, 1, // Top Right
            -1, 1, // Top Left
            1, -1, // Bottom Right
            -1, -1, // Bottom Left
            // each inner corner (indices 4, 5, 6 ,7)
            1 - inset, 1 - inset, // Top Right
            inset - 1, 1 - inset, // Top Left
            1 - inset, inset - 1, // Bottom Right
            inset - 1, inset - 1, // Bottom Left
        },
        &[_]u32{
            // top line
            1, 0, 5,
            0, 4, 5,
            // right line
            0, 2, 4,
            4, 2, 6,
            // bottom line
            6, 2, 3,
            7, 6, 3,
            // left line
            1, 5, 3,
            3, 5, 7,
        }, .draw
    );
    defer instance.deinitMesh(outlineMesh);

    // main loop
    mainloop: while(true) {
        // Polls all of the events
        instance.pollEvents();
        // enumerate all of the events
        while(try instance.enumerateEvent()) |event| {
            if(event.event == .exit){
                var i: usize = 0;
                while(i < windows.items.len) {
                    const w = windows.items[i];
                    if(w.window == event.window) {
                        _ = windows.swapRemove(i);
                        for(w.object.draws) |d|{
                            instance.deinitMesh(d);
                        }
                        w.object.deinit(windows.allocator);
                        instance.deinitWindow(w.window);
                        if(windows.items.len == 0){
                            break :mainloop;
                        }
                    } else {
                        i += 1;
                    }
                }
            }
        }
        
        for(windows.items) |window| {
            instance.submitDrawObject(window.window, window.object);
            // The solid background of all the windows might make it confusing,
            // So draw a fairly thick outline around each one,
            // With a color based on that window's ID so they are all distinct.
            var rand = std.rand.DefaultPrng.init(@intCast(window.window));
            var r = rand.random();
            const color = ZRender.Color{
                .r = r.float(f32),
                .g = r.float(f32),
                .b = r.float(f32),
                .a = r.float(f32),
            };
            instance.submitDrawObject(window.window, ZRender.DrawObject{
                .draws = &[_]ZRender.MeshHandle{outlineMesh},
                .shader = .{
                    .SolidColor = .{
                        .color = color,
                        .transform = ZRender.Transform2D.Identity
                    }
                }
            });
        }

        for(windows.items) |window| {
            instance.runFrame(window.window, .{});
        }
    }
}

// Makes all of the windows and puts them into the list
fn makeWindows(instance: ZRender.Instance, list: *std.ArrayList(WindowData)) !void {
    {
        const window = try instance.createWindow(ZRender.WindowSettings{.name = "SolidColor", .width = 256, .height = 256});
        const mesh = try instance.static_createMesh(f32,
            &[_]f32{
                //X   Y
                 1, -1,
                -1, -1,
                 0,  1,
            },
            &[_]u32{
                0, 1, 2,
        }, .draw);
        const shader = ZRender.Shader{
            .SolidColor = .{
                .color = .{.r = 1, .g = 0, .b = 1, .a = 1},
                .transform = ZRender.Transform2D.Identity,
            },
        };
        const draw = ZRender.DrawObject{
            .draws = &[1]ZRender.MeshHandle{mesh},
            .shader = shader,
        };
        try list.append(.{
            .object = try draw.duplicate(list.allocator),
            .window = window,
        });
    }
    {
        const window = try instance.createWindow(ZRender.WindowSettings{.name = "VertexColor", .width = 256, .height = 256});
        const mesh = try instance.static_createMesh(f32,
            &[_]f32{
                //X   Y  R  G  B  A
                 1, -1, 1, 0, 0, 1,
                -1, -1, 0, 1, 0, 1,
                 0,  1, 0, 0, 1, 1,
            },
            &[_]u32{
                0, 1, 2,
        }, .draw);
        const shader = ZRender.Shader{
            .VertexColor = .{
                .transform = ZRender.Transform2D.Identity,
            },
        };
        const draw = ZRender.DrawObject{
            .draws = &[1]ZRender.MeshHandle{mesh},
            .shader = shader,
        };
        try list.append(.{
            .object = try draw.duplicate(list.allocator),
            .window = window,
        });
    }
}