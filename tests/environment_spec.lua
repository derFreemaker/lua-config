local setup = require("tests.setup_lua-config")

---@type LuaFileSystem
local lfs = require("lfs")

---@type luassert
local las = require("luassert")

local org_getenv = os.getenv

context("environment", function()
    lazy_setup(function()
        setup.load()
    end)

    test("os", function()
        local os = config.env.os
        if setup.get_os() ~= "windows" then
            las.are_not_equal("windows", os)
        else
            las.are_equal("windows", os)
            las.is_true(config.env.is_windows)
        end
    end)

    test("is_root", function()
        local is_root
        if setup.get_os() == "windows" then
            is_root = io.popen("net session 2>&1"):close() ~= nil
        else
            is_root = io.popen("sudo -n true 2>&1"):close() ~= nil
        end

        las.are_equal(is_root, config.env.is_root)
    end)

    test("hostname", function()
        local hostname
        if setup.get_os() == "windows" then
            hostname = org_getenv("COMPUTERNAME")
        else
            local handle = io.popen("cat /etc/hostname", "r")
            if not handle then
                error("unable to get hostname!")
            end
            local result = handle:read("a")
            local success = handle:close()
            if not success then
                error("unable to get hostname!")
            end

            hostname = result:gsub("\n", "")
        end

        las.are_equal(hostname, config.env.hostname)
    end)

    test("get", function()
        las.are_equal(org_getenv("TERM"), config.env.get("TERM"))
    end)

    test("set", function()
        local org_hostname = org_getenv("HOSTNAME") or ""
        las.is_true(config.env.set("HOSTNAME", org_hostname .. "_test", config.env.scope.process))
        las.are_not_equal(org_hostname, org_getenv("HOSTNAME"))
    end)
end)
