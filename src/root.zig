const std = @import("std");
const zlua = @import("zlua");

const Lua = @import("common/lua.zig");

const Execute = @import("execute.zig");

const LuaConfig = struct {
    pub const __luaMeta = Lua.StructMeta{
        .name = "lua-config",
        .fields = &.{
            Lua.StructMeta.method(&execute, "execute"),
        },
        .meta_fields = &.{
            Lua.StructMeta.method(&deinit, "__gc"),
        },
    };

    const Self = @This();

    gpa: std.heap.GeneralPurposeAllocator(.{}),

    pub fn init() Self {
        return Self{
            .gpa = .init,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self.gpa.deinit();
    }

    pub fn execute(state: Lua.ThisState, self: *LuaConfig, _: Lua.Ref.Table) !Lua.ReturnStackValues {
        const lua_argv = Lua.Array.check(state.lua, self.gpa.allocator(), []const []const u8, 2);
        defer self.gpa.allocator().free(lua_argv);

        const argv = try self.gpa.allocator().alloc([]const u8, lua_argv.len);
        for (lua_argv, 0..) |lua_arg, i| {
            argv[i] = try self.gpa.allocator().dupe(u8, lua_arg);
        }

        var instance = Execute.init(self.gpa.allocator(), argv);
        if (instance.start()) |err_msg| {
            Lua.push(state.lua, err_msg);
            return .extra;
        }

        Lua.push(state.lua, instance);
        return .extra;
    }
};

pub fn luaopen(lua: *zlua.Lua) i32 {
    lua.pop(2); // pop require('name') and module path

    Lua.push(lua, LuaConfig.init());
    return 1;
}

comptime {
    _ = zlua.exportFn("lua_config", luaopen);
}
