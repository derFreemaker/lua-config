---@meta _

---@class lua-config.lib
---@field env lua-config.lib.env
local LuaConfig = {}

---@class lua-config.lib.execution
local Execution = {}

---@class lua-config.lib.execution.result
---@field success boolean
---@field exitcode integer
---@field stdout string
---@field stderr string

---@param max_output_bytes integer
---@return lua-config.lib.execution.result
function Execution:wait(max_output_bytes)
end

---@param path string
---@param args string[]
---@return lua-config.lib.execution
function LuaConfig:execute(path, args)
end

---@class lua-config.lib.env
---@field os string
---@field is_root boolean
---@field hostname string
local Env = {}
