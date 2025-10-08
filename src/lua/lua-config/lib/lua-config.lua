local lib = package.loadlib(__lua_config_dir .. "/zig-out/bin/lua_config.dll", "luaopen_lua_config")

return lib
