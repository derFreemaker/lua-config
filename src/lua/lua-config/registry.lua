---@class lua-config.registry
local registry = {}

---@param path string
---@param value_name string
function registry.read(path, value_name)
    local command = string.format('reg query "%s" /v "%s"', path, value_name)
    local output = config.env.execute(command)

    -- Parse the output to extract the registry value
    return output:match(value_name .. "%s+REG_%a+%s+(.*)")
end

---@param path string
---@param value_name string
---@param value_type string
---@param value_data string | number
function registry.write(path, value_name, value_type, value_data)
    local command = string.format(
        'reg add "%s" /v "%s" /t %s /d "%s" /f',
        path, value_name, value_type, tostring(value_data)
    )
    local output = config.env.execute(command)

    if output:find("success", 1, true) then
        return true
    else
        return false
    end
end

---@param path string
---@param value_name string
function registry.delete(path, value_name)
    local command = string.format('reg delete "%s" /v "%s" /f', path, value_name)
    local output = config.env.execute(command)

    if output:find("success", 1, true) then
        return true
    else
        return false
    end
end

local function check_windows()
    if not config.env.is_windows then
        error("registry can only be changed on windows")
    end

    if not config.env.is_admin then
        --//TODO: maybe look for 'HKCU' since that doesn't need admin privileges for most things
        error("you need admin privileges to change the registry")
    end
end
for key, value in pairs(registry) do
    if type(value) == "function" then
        registry[key] = function(...)
            check_windows()
            return value(...)
        end
    end
end

return registry
