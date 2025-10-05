const std = @import("std");
const builtin = @import("builtin");

const Lua = @import("common/lua.zig");

const Execute = @import("execute.zig");

const LuaConfig = @This();

const allocator = @import("allocator.zig").gpa.allocator();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config",
    .fields = &.{
        Lua.StructMeta.method(&execute, "execute"),
    },
    .meta_fields = &.{
        Lua.StructMeta.method(&deinit, "__gc"),
    },
};

pub fn deinit(_: *LuaConfig) void {
    switch (builtin.mode) {
        .Debug,
        .ReleaseSafe,
        => {
            _ = @import("allocator.zig").gpa.deinit();
        },
        else => {},
    }
}

pub fn execute(state: Lua.ThisState, path: []const u8, tbl: Lua.Ref.Table) !Lua.ReturnStackValues {
    const lua_argv = Lua.Array.check(state.lua, allocator, []const []const u8, tbl.ref.index);
    defer allocator.free(lua_argv);

    const argv = try allocator.alloc([]const u8, lua_argv.len + 1);
    argv[0] = try allocator.dupe(u8, path);
    for (lua_argv, 1..) |lua_arg, i| {
        argv[i] = try allocator.dupe(u8, lua_arg);
    }

    var instance = Execute.init(allocator, argv);
    if (instance.start()) |err_msg| {
        Lua.push(state.lua, err_msg);
        return .extra;
    }

    Lua.push(state.lua, instance);
    return .extra;
}
