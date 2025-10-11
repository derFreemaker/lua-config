---@return "windows" | "unix"
local function get_os()
    if package.config:sub(1, 1) == '\\' then
        return "windows"
    else
        return "unix"
    end
end

local zig_out_dir = config.root_path .. "/zig-out/"

local lib_func, msg
if get_os() == "windows" then
    lib_func, msg = package.loadlib((zig_out_dir .. "bin/lua_config.dll"):gsub("/", "\\"), "luaopen_lua_config")
else
    lib_func, msg = package.loadlib(zig_out_dir .. "lib/liblua_config.so", "luaopen_lua_config")
end

if not lib_func then
    error("unable to load lua-config library: " .. msg)
end

local success, lib_obj = pcall(lib_func)
if not success then
    error("unable to create lua-config object: " .. lib_obj)
end

return lua_obj
