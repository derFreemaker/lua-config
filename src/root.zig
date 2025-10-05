const std = @import("std");
const builtin = @import("builtin");
const zlua = @import("zlua");

const Lua = @import("common/lua.zig");

const LuaConfig = @import("lua-config.zig");

pub fn luaopen(lua: *zlua.Lua) i32 {
    lua.pop(2); // pop require('name') and module path

    Lua.push(lua, LuaConfig{});
    return 1;
}

comptime {
    _ = zlua.exportFn("lua_config", luaopen);
}
