local setup = require("tests.setup_lua-config")

---@type lfs
local lfs = require("lfs")

---@type luassert
local las = require("luassert")

---@type luasystem
local system = require("system")

local test_dir = debug.getinfo(1, "S").source:gsub("\\", "/"):sub(2):match("^(.+/)[^/]+$")

context("general", function()
    lazy_setup(function()
        setup.load()
    end)

    test("root_path", function()
        las.are_equal(test_dir, config.root_path)
    end)

    test("execute", function()
        local msg = "works"
        local path, args
        if system.windows then
            path = "powershell"
            args = { "-NoProfile", "-Command", "echo " .. msg }
        else
            path = "/bin/bash"
            args = { "--noprofile", "--norc", "-c", "echo " .. msg }
        end

        -- echo should append a new line when writing to stdout
        local expected = msg
        if system.windows then
            expected = expected .. "\r"
        end
        expected = expected .. "\n"

        local result = config.env.start_execute(path, args):wait()
        las.is_true(result.success)
        las.are_equal(expected, result.stdout)

        local result_shell = config.env.start_execute("echo " .. msg, nil, true)
        las.is_true(result.success)
        las.are_equal(expected, result.stdout)
    end)
end)
