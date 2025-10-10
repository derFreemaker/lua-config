const std = @import("std");
const builtin = @import("builtin");

const Lua = @import("common/lua.zig");

const Execute = @import("execute.zig");
const Fs = @import("fs.zig");
const Environment = @import("environment.zig");

const LuaConfig = @This();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config",
    .fields = &.{
        Lua.StructMeta.property("fs"),
        Lua.StructMeta.property("env"),

        Lua.StructMeta.method(&execute, "execute"),
    },
};

allocator: std.mem.Allocator,

fs: Fs,
env: Environment,

pub fn init(allocator: std.mem.Allocator) LuaConfig {
    return LuaConfig{
        .allocator = allocator,

        .fs = Fs.init(allocator),
        .env = Environment.init(allocator),
    };
}

pub fn execute(self: *LuaConfig, path: []const u8, tbl: Lua.Ref.Table, state: Lua.ThisState) !Lua.ReturnStackValues {
    const lua_argv = Lua.Array.check(state.lua, self.allocator, []const []const u8, tbl.ref.index);
    defer self.allocator.free(lua_argv);

    const argv = try self.allocator.alloc([]const u8, lua_argv.len + 1);
    argv[0] = try self.allocator.dupe(u8, path);
    for (lua_argv, 1..) |lua_arg, i| {
        argv[i] = try self.allocator.dupe(u8, lua_arg);
    }

    var instance = Execute.init(self.allocator, argv);
    errdefer instance.deinit();
    if (instance.start()) |err_msg| {
        state.push(.{ null, err_msg });
        return .extra;
    }

    state.push(instance);
    return .extra;
}
