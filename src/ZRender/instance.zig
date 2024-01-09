const std = @import("std");
const bits = @import("bits.zig");
const shader = @import("shader.zig");
// The primary API for ZRender

pub const InstanceOptions = struct {
    allocator: std.mem.Allocator,
};

pub const Instance = struct {
    pub fn initInstance(options: InstanceOptions) !Instance {
        _ = options;
        @panic("TODO");
    }

    pub fn deinitInstance(this: Instance) void {
        _ = this;
        @panic("TODO");
    }

    pub fn createWindow(this: Instance, options: bits.WindowSettings) !bits.WindowHandle {
        _ = this;
        _ = options;
        @panic("TODO");
    }

    pub fn deinitWindow(this: Instance, window: bits.WindowHandle) void {
        _ = this;
        _ = window;
    
        @panic("TODO");
    }

    pub fn enumerateEvent(this: Instance) !?bits.Event {
        _ = this;
    
        @panic("TODO");
    }

    pub fn createDrawObject(this: Instance, data: bits.DrawData) !bits.DrawObjectHandle {
        _ = this;
        _ = data;
    
        @panic("TODO");
    }

    pub fn deinitDrawObject(this: Instance, draw: bits.DrawObjectHandle) void {
        _ = this;
        _ = draw;
    
        @panic("TODO");
    }

    pub fn replaceDrawObject(this: Instance, draw: bits.DrawObjectHandle, data: bits.DrawData) void {
        _ = this;
        _ = draw;
        _ = data;
    
        @panic("TODO");
    }

    pub fn modifyDrawObject(this: Instance, draw: bits.DrawObjectHandle, data: bits.DrawDiff) void {
        _ = this;
        _ = draw;
        _ = data;
    
        @panic("TODO");
    }
    
    pub fn fakeUseDrawObject(this: Instance, draw: bits.DrawObjectHandle) void {
        _ = this;
        _ = draw;
    
        @panic("TODO");
    }

    pub fn submitDrawList(this: Instance, window: bits.WindowHandle) void {
        _ = this;
        _ = window;
    
        @panic("TODO");
    }

    pub fn beginDrawing(this: Instance, windows: []const bits.WindowHandle) void {
        _ = this;
        _ = windows;
    
        @panic("TODO");
    }

    pub fn finishDrawing(this: Instance) void {
        _ = this;
    
        @panic("TODO");
    }

    pub fn displayFrame(this: Instance) void {
        _ = this;
    
        @panic("TODO");
    }
};