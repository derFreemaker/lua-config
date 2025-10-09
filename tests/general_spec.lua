local setup = require("tests.setup_lua-config")

---@type LuaFileSystem
local lfs = require("lfs")

---@type luassert
local las = require("luassert")

local test_dir = debug.getinfo(1, "S").source:sub(2):match("^(.+/)[^/]+$")

context("general", function()
    lazy_setup(function()
        setup.load()
    end)

    test("root_path", function()
        las.are_equal(test_dir, config.root_path)
    end)
end)
