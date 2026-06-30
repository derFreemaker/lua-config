const std = @import("std");
const builtin = @import("builtin");

const Lua = @import("common/lua.zig");
const Environment = @import("environment.zig");
const Execute = @import("execute.zig");

const LuaConfig = @This();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config",
    .fields = &.{
        Lua.StructMeta.property("env"),

        Lua.StructMeta.method(&execute, "execute"),
    },
    .meta_fields = &.{
        Lua.StructMeta.method(&deinit, "__gc"),
    },
};

allocator: std.mem.Allocator,
threaded: std.Io.Threaded,

io: std.Io,
env_map: std.process.Environ.Map,

env: Environment,

const InitError = std.mem.Allocator.Error || error{Unexpected};

pub fn init(allocator: std.mem.Allocator) InitError!*LuaConfig {
    const instance = try allocator.create(LuaConfig);
    errdefer allocator.destroy(instance);

    var threaded = std.Io.Threaded.init(allocator, .{
        .environ = .{ .block = if (builtin.os.tag == .windows) .global else .empty },
    });
    errdefer threaded.deinit();

    instance.allocator = allocator;
    instance.threaded = threaded;

    instance.io = instance.threaded.io();
    instance.env_map = try instance.threaded.environ.process_environ.createMap(allocator);

    instance.env = Environment.init(allocator, &instance.env_map);

    return instance;
}

pub fn deinit(self: *LuaConfig) void {
    self.env_map.deinit();

    self.threaded.deinit();
}

pub fn execute(self: *LuaConfig, path: []const u8, tbl: Lua.Ref.Table, state: Lua.ThisState) !Lua.ReturnStackValues {
    const lua_argv = Lua.Array.check(state.lua, self.allocator, []const []const u8, tbl.ref.index);
    defer self.allocator.free(lua_argv);

    const argv = try self.allocator.alloc([]const u8, lua_argv.len + 1);
    argv[0] = path;
    for (lua_argv, 1..) |lua_arg, i| {
        argv[i] = lua_arg;
    }
    defer self.allocator.free(argv);

    var instance = Execute.init(self.allocator, self.io, argv) catch |err| {
        const Error = std.process.SpawnError;
        const msg = switch (err) {
            // @TODO: improve error messages
            Error.OutOfMemory => "out of memory",
            Error.FileNotFound => "file not found",
            else => "unable to spawn process",
        };

        state.push(.{ null, msg });
        return .extra;
    };
    errdefer instance.deinit();

    state.push(instance);
    return .extra;
}
