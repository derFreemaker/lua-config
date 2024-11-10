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
local parent_dir
do
    local pos = lua_config_dir:reverse():find("/", 2, true)
    parent_dir = lua_config_dir:sub(0, lua_config_dir:len() - pos + 1)
end

---@return "windows" | "unix"
local function get_os()
    if package.config:sub(1, 1) == '\\' then
        return "windows"
    else
        return "unix"
    end
end
---@param path string
---@param package_path string | nil
---@param package_cpath string | nil
local function setup_path(path, package_path, package_cpath)
    package_path = package_path or ""
    package_cpath = package_cpath or ""

    local dynamic_lib_ext = ".so"
    if get_os() == "windows" then
        dynamic_lib_ext = ".dll"
    end

    package.path = package.path .. ";" .. path .. package_path .. "?.lua"
    package.cpath = package.cpath .. ";" .. path .. package_cpath .. "?" .. dynamic_lib_ext
end
setup_path(lua_config_dir, "src/lua/", "lib/")

---@type boolean, lfs
local lfs_status, lfs = pcall(require, "lfs")
if not lfs_status then
    error("failed to load LuaFileSystem library:\n" .. lfs)
end
lfs = lfs

local argparse = require("lua-config.third-party.argparse")

---@class lua-config
---@field root_path string
---
---@field args_parser argparse.Parser
---@field args table
---
---@field env lua-config.environment
---@field path lua-config.path
---@field registry lua-config.registry
config = {
    root_path = parent_dir,

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

config.env = require("lua-config.environment")
os.getenv = config.env.get

config.path = require("lua-config.path")
config.registry = require("lua-config.registry")

do
    local call_dir = lfs.currentdir()
    if not call_dir then
        error("unable to get current dir")
    end
    -- change to parent directory of lua config dir
    lfs.chdir(config.root_path)
    setup_path(config.root_path)

    local entry_file_path = config.root_path .. "init.lua"
    if not lfs.exists(entry_file_path) then
        error("no entry file found: " .. entry_file_path)
    end

    local entry_func, entry_file_err_msg = loadfile(entry_file_path)
    if not entry_func then
        error("unable to load entry file: " .. entry_file_path .. "\n" .. entry_file_err_msg)
    end

    local entry_thread = coroutine.create(entry_func)
    local success, err_msg = coroutine.resume(entry_thread)
    if not success then
        error("error in entry file:\n" .. debug.traceback(entry_thread, err_msg))
    end

    -- change back to original working directory
    lfs.chdir(call_dir)
end
