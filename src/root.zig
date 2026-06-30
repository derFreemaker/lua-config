const std = @import("std");
const builtin = @import("builtin");

const zlua = @import("zlua");

const Allocator = @import("allocator.zig");
const Lua = @import("common/lua.zig");
const LuaConfig = @import("lua-config.zig");

pub fn luaopen(lua: *zlua.Lua) i32 {
    Lua.push(lua, Allocator.init());
    const allocator = (Lua.get(lua, *Allocator, -1) catch unreachable).value;
    lua.setField(zlua.registry_index, "lua-config_allocator_lkjasdoiuwer");

    const lua_config = LuaConfig.init(allocator.allocator()) catch |err| {
        lua.raiseErrorStr(@errorName(err), .{});
    };
    Lua.push(lua, lua_config);
    return 1;
}

comptime {
    _ = zlua.exportFn("lua_config", luaopen);
}
