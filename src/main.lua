---@param path string
---@param ... string
---@return string, string[]
local function sepperate_args(path, ...)
    return path, { ... }
end
local lua_config_dir, args = sepperate_args(...)
if not lua_config_dir then
    error("no lua_config_dir provided as first argument (is the root directory of lua-config)")
end

lua_config_dir = lua_config_dir:gsub("\\", "/")
if lua_config_dir:sub(lua_config_dir:len()) ~= "/" then
    lua_config_dir = lua_config_dir .. "/"
end
---@diagnostic disable-next-line: lowercase-global
__lua_config_dir = lua_config_dir

---@param path string
---@return string
local function get_parent_dir(path)
    local pos = path:reverse():find("/", 2, true)
    return path:sub(0, path:len() - pos + 1)
end
local parent_dir = get_parent_dir(lua_config_dir)

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

    package.path = path .. package_path .. "?.lua" .. ";" .. package.path
    package.cpath = path .. package_cpath .. "?" .. dynamic_lib_ext .. ";" .. package.cpath
end
setup_path(lua_config_dir, "src/lua/")


local lib_status, lib = pcall(require, "lua-config.lib.lua-config")
if not lib_status then
    error("failed to load lua-config library:\n" .. lib)
end

local argparse = require("lua-config.third-party.argparse")

---@class lua-config
---@field fs lua-config.lib.fs
---
---@field root_path string
---
---@field args_parser argparse.Parser
---@field args table
---
---@field env lua-config.environment
---@field path lua-config.path
---@field registry lua-config.registry
config = {
    fs = lib.fs,

    root_path = parent_dir,

    args_parser = argparse("lua-config", "configuration loader in lua"),
    args = args,
}
setmetatable(config, { __lib = lib }) -- keep 'lib' alive and accessable
local parsed = false
function config.parse_args()
    if parsed then
        return
    end

    config.args = config.args_parser:parse(config.args)
    parsed = true
end

config.env = require("lua-config.environment")

config.path = require("lua-config.path")
config.registry = require("lua-config.registry")

local call_dir = config.fs.currentdir()
if not call_dir then
    error("unable to get current dir")
end
-- change to parent directory of lua config dir
config.fs.chdir(config.root_path)
setup_path(config.root_path)

local entry_file_path = "init.lua"
if not config.fs.exists(entry_file_path) then
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
config.fs.chdir(call_dir)
