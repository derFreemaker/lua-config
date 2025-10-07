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
print(lua_config)

local foo = lua_config.execute("clang", { "--version" })
print(foo)

local result = foo:wait()
print(result)
print(result.success, result.exitcode)
print(result.stdout)

print(lua_config.fs)
print(lua_config.fs.exists("test.lua"))
print(lua_config.fs.currentdir())
print(lua_config.fs.chdir("src"))
print(lua_config.fs.currentdir())
print(lua_config.fs.chdir(".."))
print(lua_config.fs.currentdir())

for file in lua_config.fs.dir("src") do
    print(file)
end

print(lua_config.fs.mkdir("test-dir"))
print(lua_config.fs.rmdir("test-dir"))

print("$END$")
