local version = "0.1"
print("lua-config version " .. version)

---@param path string
---@param ... string
---@return string, string[]
local function sepperate_args(path, ...)
    return path or "F:/Coding/Lua/lua-config", { ... }
end
local lua_config_dir, args = sepperate_args(...)
lua_config_dir = lua_config_dir:gsub("\\", "/")
if lua_config_dir:sub(lua_config_dir:len()) ~= "/" then
    lua_config_dir = lua_config_dir .. "/"
end
lua_config_dir = lua_config_dir

---@return "windows" | "unix"
local function get_os()
    if package.config:sub(1, 1) == '\\' then
        return "windows"
    else
        return "unix"
    end
end

---@param path string
---@param package_path string
---@param package_cpath string
local function setup_path(path, package_path, package_cpath)
    local dynamic_lib_ext = ".so"
    if get_os() == "windows" then
        dynamic_lib_ext = ".dll"
    end

    package.path = package.path .. ";" .. path .. package_path .. "/?.lua"
    package.cpath = package.cpath .. ";" .. path .. package_cpath .. "/?" .. dynamic_lib_ext
end
setup_path(lua_config_dir, "src/lua", "lib")

---@type boolean, lfs
local lfs_status, lfs = pcall(require, "lfs")
if not lfs_status then
    error("failed to load LuaFileSystem library:\n" .. lfs)
end
local current_dir = lfs.currentdir()
if not current_dir then
    error("was unable to get current dir.")
end

local argparse = require("lua-config.third-party.argparse")

---@class lua-config
---@field _version string
---
---@field args_parser argparse.Parser
---@field args table
config = {
    _version = version,

    args_parser = argparse("lua-config", "configuration loader in lua"),
    args = args,
}
local parsed = false
function config.parse_args()
    if parsed then
        return
    end

    config.args = config.args_parser:parse(config.args)
    parsed = true
end

require("lua-config.environment")

do
    local main_file_path = lua_config_dir .. "../init.lua"
    if not lfs.exists(main_file_path) then
        print("no " .. main_file_path .. " file found!")
        os.exit(1)
    end

    local main_func, main_file_err_msg = loadfile(main_file_path)
    if not main_func then
        print("unable to load main file: " .. main_file_path .. "\n" .. main_file_err_msg)
        os.exit(1)
    end

    local main_thread = coroutine.create(main_func)
    local success, err_msg = coroutine.resume(main_thread)
    if not success then
        print("error in main file:\n" .. debug.traceback(main_thread, err_msg))
        os.exit(1)
    end
end
