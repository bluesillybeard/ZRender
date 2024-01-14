const std = @import("std");
const zrender = @import("zrender.zig");
const shader = @import("shader.zig");
const mockInstance = @import("mockInstance.zig");

pub const InstanceOptions = struct {
    allocator: std.mem.Allocator,
};

pub const Instance = struct {
    object: *anyopaque,
    vtable: *Vtable,
    /// Creates an instance
    pub fn initInstance(options: InstanceOptions) !Instance {
        return makeInstance(mockInstance.MockInstance, try mockInstance.MockInstance.init(options));
    }

    /// Destroyes an instance.
    /// Note that this does not destroy 
    pub fn deinitInstance(this: Instance) void {
        this.vtable.deinitInstance(this.object);
    }

    pub fn createWindow(this: Instance, options: zrender.WindowSettings) errors.CreateWindowError!zrender.WindowHandle {
        return this.vtable.createWindow(this.object, options);
    }

    pub fn deinitWindow(this: Instance, window: zrender.WindowHandle) void {
        this.vtable.deinitWindow(this.object, window);
    }

    pub fn enumerateEvent(this: Instance) errors.EnumerateEventError!?zrender.Event {
        return this.vtable.enumerateEvent(this.object);
    }

    pub fn createMeshObject(this: Instance, data: zrender.MeshData) errors.CreateMeshObjectError!zrender.MeshObjectHandle {
        return this.vtable.createMeshObject(this.object, data);
    }

    pub fn deinitMeshObject(this: Instance, mesh: zrender.MeshObjectHandle) void {
        this.vtable.deinitMeshObject(this.object, mesh);
    }

    pub fn createDrawObject(this: Instance, mesh: zrender.MeshObjectHandle, shaderType: zrender.shader.ShaderType) errors.CreateDrawObjectError!zrender.DrawObjectHandle {
        return this.vtable.createDrawObject(this.object, mesh, shaderType);
    }

    pub fn deinitDrawObject(this: Instance, draw: zrender.DrawObjectHandle) void {
        this.vtable.deinitDrawObject(this.object, draw);
    }

    pub fn replaceDrawObject(this: Instance, draw: zrender.DrawObjectHandle, mesh: zrender.MeshObjectHandle) void {
        this.vtable.replaceDrawObject(this.object, draw, mesh);
    }

    pub fn modifyDrawObject(this: Instance, draw: zrender.DrawObjectHandle, data: zrender.DrawDiff) void {
        this.vtable.modifyDrawObject(this.object, draw, data);
    }

    pub fn beginFrame(this: Instance, args: zrender.BeginFrameArgs) void {
        this.vtable.beginFrame(this.object, args);
    }

    /// It is undefined to submit a draw object with a different shader type to the given data.
    pub fn submitDrawList(this: Instance, window: zrender.WindowHandle, draws: []const zrender.DrawObject) void {
        this.vtable.submitDrawList(this.object, window, draws);
    }

    pub fn finishFrame(this: Instance, args: zrender.FinishFrameArgs) void {
        this.vtable.finishFrame(this.object, args);
    }
};

pub const errors = struct {
    pub const InitInstanceError = error {
        /// returned when there is no supported backend available
        noSupportedBackend,
    } || std.mem.Allocator.Error;

    pub const CreateWindowError = error {
        // TODO: replace this with more specific errors
        createWindowError,
    } || std.mem.Allocator.Error;

    pub const EnumerateEventError = error {
        // TODO: replace this with more specific errors
        enumerateEventError,
    } || std.mem.Allocator.Error;

    pub const CreateDrawObjectError = error {
        createDrawObjectError,
    } || std.mem.Allocator.Error;

    pub const CreateMeshObjectError = error {
        createMeshObjectError,
    } || std.mem.Allocator.Error;
};

const Vtable = struct {
    deinitInstance:    *const fn (this: *anyopaque) void,
    createWindow:      *const fn (this: *anyopaque, options: zrender.WindowSettings) errors.CreateWindowError!zrender.WindowHandle,
    deinitWindow:      *const fn (this: *anyopaque, window: zrender.WindowHandle) void,
    enumerateEvent:    *const fn (this: *anyopaque) errors.EnumerateEventError!?zrender.Event,
    createDrawObject:  *const fn (this: *anyopaque, data: zrender.DrawData) errors.CreateDrawObjectError!zrender.DrawObjectHandle,
    deinitDrawObject:  *const fn (this: *anyopaque, draw: zrender.DrawObjectHandle) void,
    replaceDrawObject: *const fn (this: *anyopaque, draw: zrender.DrawObjectHandle, data: zrender.DrawData) void,
    modifyDrawObject:  *const fn (this: *anyopaque, draw: zrender.DrawObjectHandle, data: zrender.DrawDiff) void,
    fakeUseDrawObject: *const fn (this: *anyopaque, draw: zrender.DrawObjectHandle) void,
    beginFrame:        *const fn (this: *anyopaque, args: zrender.BeginFrameArgs) void,
    submitDrawList:    *const fn (this: *anyopaque, window: zrender.WindowHandle, draws: []const zrender.DrawObject) void,
    finishFrame:       *const fn (this: *anyopaque, args: zrender.FinishFrameArgs) void,
};

pub fn makeInstance(comptime Impl: type, impl: *Impl) Instance {
    const objectTypeInfo = @typeInfo(Impl);

    if (objectTypeInfo != .Struct) {
        @compileError("Object must be a struct");
    }

    // build the vtable
    const vtableInfo = @typeInfo(Vtable);
    // Needs to be comptime so it is embedded into the output artifact instead of being on the stack.
    comptime var vtable: Vtable = undefined;

    inline for (vtableInfo.Struct.fields) |field| {
        if (!@hasDecl(Impl, field.name)) @compileError("Object does not implement " ++ field.name);
        const decl = @field(Impl, field.name);
        // make sure the decl is a function with the right parameters
        const declInfo = @typeInfo(@TypeOf(decl));

        switch (declInfo) {
            .Fn => |implFn| {
                const vtableFn = @typeInfo(@typeInfo(field.type).Pointer.child).Fn;
                comptime implementationFunctionValid(vtableFn, implFn) catch |err| {
                    @compileLog(err);
                    @compileError("Function signatures for " ++ field.name ++ " are incompatible!");
                };
                @field(vtable, field.name) = @ptrCast(&decl);
            },
            else => {
                @compileError("Implementation of " ++ field.name ++ " Must be a function");
            },
        }
    }

    return .{
        .object = impl,
        .vtable = &vtable,
    };
}


fn implementationFunctionValid(comptime vtableFn: std.builtin.Type.Fn, comptime implementerFn: std.builtin.Type.Fn) !void {
    // A's allignment must be <= to B's, because otherwise B might be placed at an offset that is uncallable from A.
    if (vtableFn.alignment > implementerFn.alignment) {
        @compileLog("Allignment doesn't match");
        return error.alignment_doesnt_match;
    }
    if (vtableFn.calling_convention != implementerFn.calling_convention) {
        @compileLog("Calling convention doesn't match");
        return error.calling_conv_doesnt_match;
    }
    if (vtableFn.is_generic != implementerFn.is_generic) {
        @compileLog("The vtableFn and the implementerFn must both be generic or neither be generic");
        return error.generic_status_doesnt_match;
    }
    if (vtableFn.is_var_args != implementerFn.is_var_args) {
        @compileLog("One is var args, the other isn't");
        return error.var_args_doesnt_match;
    }
    if (vtableFn.params.len != implementerFn.params.len) {
        @compileLog("Wrong number of parameters");
        return error.wrong_number_of_parameters;
    }

    // TODO if A returns anyopaque, let B return any pointer
    // TODO: options.allow_bitwise_compatibility
    if (vtableFn.return_type != implementerFn.return_type) {
        @compileLog("Wrong return type");
        return error.wrong_return_type;
    }
    // For each parameter
    inline for (vtableFn.params, 0..) |parameter_vt, index| {
        const parameter_impl = implementerFn.params[index];
        if (parameter_vt.is_generic != parameter_impl.is_generic) return false;
        if (parameter_vt.is_noalias != parameter_impl.is_noalias) return false;
        if (parameter_vt.type == *anyopaque) {
            if (parameter_impl.type == null) {
                return error.parameter_impl_type_is_null;
            }
            const parameter_b_info = @typeInfo(parameter_impl.type.?);
            if (parameter_b_info != .Pointer) {
                @compileLog(std.fmt.comptimePrint("Parameter {} isn't a pointer", .{index}));
                return error.parameter_isnt_pointer;
            }
        } else {
            if (parameter_vt.type != parameter_impl.type) {
                return error.parameter_type_doesnt_match;
            }
        }
    }

    // If all the above checks succeed, then return true.
    //return true;
}