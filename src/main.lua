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

do
    local version_file = io.open(lua_config_dir .. "VERSION", "r")
    if not version_file then
        error("unable to open version file!")
    end
    local version = version_file:read("l")
    print("lua-config version " .. version)
end

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
---@field args_parser argparse.Parser
---@field args table
config = {
    args_parser = argparse("lua-config", "configuration loader in lua")
}
local parsed = false
function config.parse_args()
    if parsed then
        return
    end

    config.args = config.args_parser:parse(args)
    parsed = true
end

require("lua-config.environment")
