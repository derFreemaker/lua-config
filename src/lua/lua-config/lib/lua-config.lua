---@return "windows" | "unix"
local function get_os()
    if package.config:sub(1, 1) == '\\' then
        return "windows"
    else
        return "unix"
    end
end

local lib_func, msg
if get_os() == "windows" then
    lib_func, msg = package.loadlib(__lua_config_dir .. "/zig-out/bin/lua_config.dll", "luaopen_lua_config")
else
    lib_func, msg = package.loadlib(__lua_config_dir .. "/zig-out/lib/liblua_config.so", "luaopen_lua_config")
end

if not lib_func then
    error("unable to load lua-config library: " .. msg)
end

local success, lib_obj = pcall(lib_func)
if not success then
    error("unable to create lua-config object: " .. lib_obj)
end

return lua_obj
