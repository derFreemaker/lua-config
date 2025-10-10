local setup = require("tests.setup_lua-config")

---@type LuaFileSystem
local lfs = require("lfs")

---@type luassert
local las = require("luassert")

context("fs", function()
    local mkdir_path = "tests/fs_tests/mkdir_test"
    local rmdir_path = "tests/fs_tests/rmdir_test"

    local symlink_file_path = "tests/fs_tests/symlink_file"
    local symlink_file_target = "tests/fs_tests/symlink_file_target"
    local symlink_dir_path = "tests/fs_tests/symlink_dir"
    local symlink_dir_target = "tests/fs_tests"

    local symlink_dir_file_check = symlink_dir_path .. "/symlink_file_target"

    lazy_setup(function()
        setup.load()

        if not lfs.attributes(rmdir_path) then
            las.is_true(lfs.mkdir(rmdir_path))
        end
    end)

    teardown(function()
        if lfs.attributes(mkdir_path) then
            las.is_true(lfs.rmdir(mkdir_path))
        end
        if lfs.attributes(symlink_file_path) then
            las.is_true(os.remove(symlink_file_path))
        end
        if lfs.attributes(symlink_dir_path) then
            if setup.get_os() == "windows" then
                las.is_true(os.execute("rmdir " .. symlink_dir_path:gsub("/", "\\")))
            else
                las.is_true(os.remove(symlink_dir_path))
            end
        end
    end)

    test("chdir", function()
        local start_dir = lfs.currentdir()
        las.is_true(config.fs:chdir("tests/fs_tests"))
        las.is_true(lfs.chdir("../.."))
        las.are_equal(start_dir, lfs.currentdir())
    end)

    test("currentdir", function()
        las.are_equal(lfs.currentdir(), config.fs:currentdir())
    end)

    test("exists", function()
        las.is_true(config.fs:exists("tests"))
    end)

    test("dir", function()
        local config_iter = config.fs:dir(".")
        for file in lfs.dir(".") do
            if file == "." or file == ".." then
                -- we skip these lua-config doesn't show these
                goto continue
            end

            las.are_equal(file, config_iter())

            ::continue::
        end
    end)

    test("mkdir", function()
        las.is_true(config.fs:mkdir(mkdir_path))
        las.is_not_nil(lfs.attributes(mkdir_path))
    end)

    test("rmdir", function()
        las.is_true(config.fs:rmdir(rmdir_path))
        las.is_nil(lfs.attributes(rmdir_path))
    end)

    test("create_symlink", function()
        if setup.get_os() == "windows" and not config.env.is_root then
            error("can only be done with elevated privileges on windows")
        end

        las.is_true(config.fs:create_symlink(symlink_file_path, symlink_file_target, false))
        las.is_not_nil(lfs.attributes(symlink_file_path))

        las.is_true(config.fs:create_symlink(symlink_dir_path, symlink_dir_target, true))
        las.is_not_nil(lfs.attributes(symlink_dir_file_check))
    end)
end)
