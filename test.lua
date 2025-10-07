---@return "windows" | "unix"
local function get_os()
    if package.config:sub(1, 1) == '\\' then
        return "windows"
    else
        return "unix"
    end
end
if get_os() == "windows" then
    package.cpath = "F:\\coding\\lua-config\\zig-out\\bin\\?.dll"
else
    package.cpath = "./zig-out/lib/lib?.so"
end
local lua_config = require("lua_config")

local result = lua_config.execute("clang", { "--version" }):wait()
print(result.success, result.exitcode)
print(result.stdout)

print("exists", lua_config.fs.exists("test.lua"))
print("currentdir", lua_config.fs.currentdir())
print("chdir", lua_config.fs.chdir("src"))
print("currentdir", lua_config.fs.currentdir())
print("chdir", lua_config.fs.chdir(".."))
print("currentdir", lua_config.fs.currentdir())

print()
print("dir:")
for file in lua_config.fs.dir("src") do
    print(file)
end
print()

print("mkdir", lua_config.fs.mkdir("test-dir"))
print("create_symlink", lua_config.fs.create_symlink("test-dir-link", "test-dir", true))
print("os.remove", os.remove("test-dir-link"))
print("rmdir", lua_config.fs.rmdir("test-dir"))

print("$END$")
