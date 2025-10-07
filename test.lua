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

print("--- lua_config.execute:")
local result = lua_config.execute("clang", { "--version" }):wait()
print(result.success, result.exitcode)
print(result.stdout)
print()

print("--- start: lua_config.fs")

print("lua_config.fs.exists", lua_config.fs.exists("test.lua"))
print("lua_config.fs.currentdir", lua_config.fs.currentdir())
print("lua_config.fs.chdir", lua_config.fs.chdir("src"))
print("lua_config.fs.currentdir", lua_config.fs.currentdir())
print("lua_config.fs.chdir", lua_config.fs.chdir(".."))
print("lua_config.fs.currentdir", lua_config.fs.currentdir())

print("--- lua_config.fs.dir:")
for file in lua_config.fs.dir("src") do
    print(file)
end
print()

print("lua_config.fs.mkdir", lua_config.fs.mkdir("test-dir"))
print("lua_config.fs.create_symlink", lua_config.fs.create_symlink("test-dir-link", "test-dir", true))
print("os.remove", os.remove("test-dir-link"))
print("lua_config.fs.rmdir", lua_config.fs.rmdir("test-dir"))

print("--- end: lua_config.fs")
print("--- start: lua_config.env")

print("lua_config.env.os", lua_config.env.os)
print("lua_config.env.is_windows", lua_config.env.is_windows)
print("lua_config.env.is_root", lua_config.env.is_root)
print("lua_config.env.hostname", lua_config.env.hostname)

print("lua_config.env.get", lua_config.env.get("HOME"))
print("lua_config.env.set", lua_config.env.set("HOME", "~/test-home"))
print("lua_config.env.get", lua_config.env.get("HOME"))

print("--- end: lua_config.env")

print("$END$")
