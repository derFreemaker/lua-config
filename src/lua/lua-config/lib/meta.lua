---@meta _

---@class lua-config.lib
---@field fs lua-config.lib.fs
---@field env lua-config.lib.env
local LuaConfig = {}

---@class lua-config.lib.execution
local Execution = {}

---@class lua-config.lib.execution.result
---@field success boolean
---@field exitcode integer
---@field stdout string
---@field stderr string

---@return lua-config.lib.execution.result
function Execution:wait()
end

---@param path string
---@param args string[]
---@return lua-config.lib.execution
function LuaConfig.execute(path, args)
end

---@class lua-config.lib.fs
local Fs = {}

---@param path string
---@return boolean
function Fs.chdir(path)
end

---@return string?
function Fs.currentdir()
end

---@param path string
---@return boolean
function Fs.exists(path)
end

---@class lua-config.lib.fs.dir
local Dir = {}

function Dir:close()
end

function Dir:next()
end

---@param path string
---@return fun() : string?
---@return lua-config.lib.fs.dir
function Fs.dir(path)
end

---@param path string
---@return boolean
function Fs.mkdir(path)
end

---@param path string
---@return boolean
function Fs.rmdir(path)
end

---@param path string
---@param target string
---@param is_directory boolean
---@return boolean
function Fs.create_symlink(path, target, is_directory)
end

---@class lua-config.lib.env
---@field os string
---@field is_windows boolean
---@field is_root boolean
---@field hostname string
local Env = {}

---@param name string
---@return string
function Env.get(name)
end

---@param name string
---@param value string
---@return boolean
function Env.set(name, value)
end
