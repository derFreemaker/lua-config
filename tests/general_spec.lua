local setup = require("tests.setup_lua-config")

---@type lfs
local lfs = require("lfs")

---@type luassert
local las = require("luassert")

---@type luasystem
local system = require("system")

context("general", function()
    lazy_setup(function()
        setup.load()
    end)

    test("root_path", function()
        ---@param path string
        ---@return string
        local function get_parent_dir(path)
            local pos = path:reverse():find("/", 2, true)
            if not pos then
                return path
            end
            return path:sub(0, path:len() - pos + 1)
        end
        local test_dir = get_parent_dir(debug.getinfo(1, "S").source:gsub("\\", "/"):sub(2))

        if test_dir:sub(0, 2) == "./" then
            test_dir = test_dir:sub(3)
        end

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

        local execution, err_msg = config.env.start_execute(path, args)

        las.is_nil(err_msg)
        las.is_not_nil(execution)
        ---@cast execution -nil

        local result = execution:wait(1024 * 1024)
        las.is_true(result.success)
        las.are_equal(expected, result.stdout)

        local result_shell = config.env.start_execute("echo " .. msg, nil, true):wait(1024 * 1024)
        las.is_true(result_shell.success)
        las.are_equal(expected, result_shell.stdout)
    end)
end)
