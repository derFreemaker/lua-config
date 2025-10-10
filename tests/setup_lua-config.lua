---@return "windows" | "unix"
local function get_os()
    if package.config:sub(1, 1) == '\\' then
        return "windows"
    else
        return "unix"
    end
end

local tests_dir = debug.getinfo(1, "S").source:gsub("\\", "/"):sub(4):match("^(.+)/[^/]+$")

---@type lfs
local lfs = require("lfs")

---@type luassert
local las = require("luassert")

return {
    load = function()
        local start_dir = lfs.currentdir()
        if get_os() == "windows" then
            local config_func = loadfile(tests_dir:gsub("/", "\\") .. "\\..\\src\\main.lua")
            if not config_func then
                error(config_func)
            end
            config_func(tests_dir .. "/..")
        else
            local config_func = loadfile(tests_dir .. "/../src/main.lua")
            if not config_func then
                error(config_func)
            end
            config_func(tests_dir .. "/..")
        end
        las.are_same(start_dir, lfs.currentdir())
    end,
    get_os = get_os,
}
