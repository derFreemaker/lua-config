local lib = package.loadlib(__lua_config_dir .. "/zig-out/bin/lua_config.dll", "luaopen_lua_config")
if not lib then
    error("unable to load lua-config library")
end

return lib()
