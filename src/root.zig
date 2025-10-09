const std = @import("std");
const builtin = @import("builtin");
const zlua = @import("zlua");

const Lua = @import("common/lua.zig");

const LuaConfig = @import("lua-config.zig");

pub fn luaopen(lua: *zlua.Lua) i32 {
    Lua.push(lua, LuaConfig.init());
    return 1;
}

comptime {
    _ = zlua.exportFn("lua_config", luaopen);
}
