const std = @import("std");
const zlua = @import("zlua");

const Lua = @import("lua.zig");

pub const LuaFieldMeta = union(enum) {
    property: PropertyMeta,
    method: MethodMeta,

    pub const PropertyMeta = struct {
        name: []const u8,
        luaName: [:0]const u8,

        readonly: bool,
    };

    pub fn initProperty(name: []const u8, lua_name: [:0]const u8) LuaFieldMeta {
        return LuaFieldMeta{
            .property = .{
                .name = name,
                .luaName = lua_name,

                .readonly = true,
            },
        };
    }

    pub const MethodType = enum {
        method,
        getter,
        setter,
    };

    pub const MethodMeta = struct {
        luaName: [:0]const u8,
        type: MethodType,

        ptr_type: type,
        ptr: *const anyopaque,
    };

    pub fn initMethod(func: anytype, lua_name: [:0]const u8) LuaFieldMeta {
        return LuaFieldMeta{
            .method = .{
                .luaName = lua_name,
                .type = .method,

                .ptr_type = @TypeOf(func),
                .ptr = @ptrCast(func),
            },
        };
    }

    pub fn luaName(comptime self: *const LuaFieldMeta) [:0]const u8 {
        return switch (self.*) {
            .property => |p| p.luaName,
            .method => |m| m.luaName,
        };
    }

    pub fn push(comptime self: *const LuaFieldMeta, lua: *zlua.Lua, comptime T: type, struct_ptr: anytype) void {
        switch (self.*) {
            .property => |p| {
                const FieldT: type = @FieldType(T, p.name);
                if (comptime Lua.itemLen(FieldT) > 1) {
                    @compileError(std.fmt.comptimePrint("multiple values not supported: '{s}' (T: {s})", .{ p.name, @typeName(T) }));
                }

                const value = switch (@typeInfo(FieldT)) {
                    .@"struct",
                    .@"union",
                    => &@field(struct_ptr.*, p.name),

                    else => @field(struct_ptr.*, p.name),
                };

                Lua.push(lua, value);
            },
            .method => |m| {
                switch (m.type) {
                    .method => Lua.push(lua, Lua.wrap(@as(m.ptr_type, @ptrCast(@alignCast(m.ptr))).*)),
                    .getter => {
                        Lua.wrap(@as(m.ptr_type, @ptrCast(@alignCast(m.ptr))).*)(@ptrCast(lua));
                    },
                    .setter => lua.pushNil(),
                }
            },
        }
    }

    pub fn set(comptime self: *const LuaFieldMeta, lua: *zlua.Lua, comptime T: type, struct_ptr: *T) void {
        switch (self.*) {
            .property => |p| {
                const FieldT: type = @FieldType(T, p.name);

                if (p.readonly) {
                    lua.raiseErrorStr("can not overwrite a readonly property: %s", .{p.name.ptr});
                }

                @field(struct_ptr.*, p.name) = Lua.check(lua, FieldT, 3);
            },
            .method => |m| {
                switch (m.type) {
                    .method => lua.raiseErrorStr("can not overwrite a method: %s", .{m.luaName.ptr}),
                    .getter => lua.raiseErrorStr("can not overwrite a getter: %s", .{m.luaName.ptr}),
                    .setter => {
                        _ = Lua.wrap(@as(m.ptr_type, @ptrCast(m.ptr)))(@ptrCast(lua));
                    },
                }
            },
        }
    }

    pub fn as(comptime self: *const LuaFieldMeta, lua_name: [:0]const u8) LuaFieldMeta {
        switch (self.*) {
            .property => |p| {
                var copy: PropertyMeta = p;
                copy.luaName = lua_name;
                return LuaFieldMeta{ .property = copy };
            },
            .method => |m| {
                var copy: PropertyMeta = m;
                copy.luaName = lua_name;
                return LuaFieldMeta{ .method = copy };
            },
        }
    }

    pub fn mutable(comptime self: *const LuaFieldMeta) LuaFieldMeta {
        if (self.* != .property) {
            @compileError("lua field meta needs to be a 'property'");
        }

        var copy: PropertyMeta = self.property;
        copy.readonly = false;
        return LuaFieldMeta{ .property = copy };
    }

    pub fn isSetterFor(comptime self: *const LuaFieldMeta, lua_name: [:0]const u8) LuaFieldMeta {
        if (self.* != .method) {
            @compileError("lua field meta needs to be a 'method'");
        }

        var copy: MethodMeta = self.method;
        copy.luaName = lua_name;
        copy.type = .setter;
        return LuaFieldMeta{ .method = copy };
    }

    pub fn isGetterFor(comptime self: *const LuaFieldMeta, lua_name: [:0]const u8) LuaFieldMeta {
        if (self.* != .method) {
            @compileError("lua field meta needs to be a 'method'");
        }

        var copy: MethodMeta = self.method;
        copy.luaName = lua_name;
        copy.type = .getter;
        return LuaFieldMeta{ .method = copy };
    }
};

pub fn method(func: anytype, lua_name: [:0]const u8) LuaFieldMeta {
    if (@typeInfo(@TypeOf(func)) != .pointer) {
        @compileError("expected pointer to function");
    }

    return LuaFieldMeta.initMethod(func, lua_name);
}

pub fn property(name: [:0]const u8) LuaFieldMeta {
    return LuaFieldMeta.initProperty(name, name);
}

const LuaStructMeta = @This();

name: ?[:0]const u8 = null,
fields: ?[]const LuaFieldMeta = null,
meta_fields: ?[]const LuaFieldMeta = null,

pub fn from(comptime T: type) ?LuaStructMeta {
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            for (s.decls) |decl| {
                const value = @field(T, decl.name);
                if (@TypeOf(value) == LuaStructMeta) {
                    return value;
                }
            }
            return null;
        },

        .@"union" => |u| {
            _ = u;
            @compileError("not implemented");
        },

        else => return null,
    }
}
