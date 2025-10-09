---@return "windows" | "unix"
local function get_os()
    if package.config:sub(1, 1) == '\\' then
        return "windows"
    else
        return "unix"
    end
end

local lib, msg
if get_os() == "windows" then
    lib, msg = package.loadlib(__lua_config_dir .. "/zig-out/bin/lua_config.dll", "luaopen_lua_config")
else
    lib, msg = package.loadlib(__lua_config_dir .. "/zig-out/lib/liblua_config.so", "luaopen_lua_config")
end

if not lib then
    error("unable to load lua-config library: " .. msg)
end

return lib()
