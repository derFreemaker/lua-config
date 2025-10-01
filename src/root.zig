const std = @import("std");

const zlua = @import("zlua");

pub fn luaopen(lua: *zlua.Lua) i32 {
    _ = lua.pushStringZ("test");
    return 1;
}

comptime {
    _ = zlua.exportFn("lua_config", luaopen);
}
