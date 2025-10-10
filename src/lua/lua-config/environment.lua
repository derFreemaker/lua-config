---@type luasystem
local system = require("system")

local utils = require("lua-config.third-party.utils")

local get_user_template =
"$e = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(\"Environment\"); Write-Output $e.GetValue(\"%s\"); $e.Close()"
local set_user_template =
"$e = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(\"Environment\", $true); Write-Output $e.SetValue(\"%s\", \"%s\"); $e.Close()"
local delete_user_template =
"$e = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(\"Environment\", $true); Write-Output $e.DeleteValue(\"%s\"); $e.Close()"

local get_machine_template =
"$e = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(\"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment\"); Write-Output $e.GetValue(\"%s\"); $e.Close()"
local set_machine_template =
"$e = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(\"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment\", $true); Write-Output $e.SetValue(\"%s\", \"%s\"); $e.Close()"
local delete_machine_template =
"$e = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(\"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment\", $true); Write-Output $e.DeleteValue(\"%s\"); $e.Close()"

---@enum lua-config.environment.variable.scope
local Scope = {
    process = 1,
    user = 2,
    machine = 3,
}

---@type lua-config.lib
---@diagnostic disable-next-line: assign-type-mismatch
local lib = getmetatable(config).__lib

---@class lua-config.environment
---@field package cache table<string, table<lua-config.environment.variable.scope, string>>
---
---@field os "windows" | "unix"
---@field is_windows boolean
---@field is_root boolean
---
---@field hostname string
local ENV = {
    os = lib.env.os,
    is_windows = system.windows,
    is_root = lib.env.is_root,

    hostname = lib.env.hostname,

    cache = {},
    scope = Scope,
}

function ENV.check_root()
    if ENV.is_root then
        return
    end

    error("elevated privileges needed")
end

---@class lua-config.execution

-- When `in_shell` is `true` will use 'powershell' on windows and '/bin/bash' on any other machine.
-- With no profile to provide better consistency
---@param command string
---@param args string[]?
---@param in_shell boolean?
---@return lua-config.lib.execution
function ENV.start_execute(command, args, in_shell)
    if not in_shell then
        return lib:execute(command, args or {})
    end

    local path, new_args
    command = command
        :gsub([[\"]], [[\\"]])
        :gsub([["]], [[\"]])
    if ENV.is_windows then
        path = "powershell.exe"
        new_args = { "-NoProfile", "-Command", command .. " " .. table.concat(args or {}, " ") }
    else
        path = "/bin/bash"
        new_args = { "--noprofile", "--norc", "-c", command .. " " .. table.concat(args or {}, " ") }
    end

    local command_to_execute = command
        :gsub([[\"]], [[\\"]])
        :gsub([["]], [[\"]])
    if args then
        command_to_execute = command_to_execute .. " "
        for i, arg in ipairs(args) do
            command_to_execute = command_to_execute .. "\""
            command_to_execute = arg
                :gsub([[\"]], [[\\"]])
                :gsub([["]], [[\"]])
            command_to_execute = command_to_execute .. "\""

            if args[i + 1] then
                command_to_execute = command_to_execute .. " "
            end
        end
    end

    return lib:execute(path, new_args)
end

-- When `in_shell` is `true` will use 'powershell' on windows and '/bin/bash' on any other machine.
-- With no profile to provide better consistency
---@param command string
---@param args string[]?
---@param in_shell boolean?
---@return lua-config.lib.execution.result
function ENV.execute(command, args, in_shell)
    return ENV.start_execute(command, args, in_shell):wait()
end

--- With 'nil' scope will return all data from user and machine
---@param name string
---@param scope lua-config.environment.variable.scope | nil
---@param ignore_cache boolean?
---@return string?
function ENV.get(name, scope, ignore_cache)
    scope = scope or Scope.process
    ---@cast scope -string

    if not ignore_cache then
        local variable = ENV.cache[name]
        if variable and variable[scope] then
            return variable[scope]
        end
    end

    ---@type string | nil
    local value
    if scope >= Scope.process then
        value = system.getenv(name)
    end

    if scope >= Scope.user then
        if not ENV.is_windows then
            error("not implemented")
        end

        local result = ENV.execute(get_user_template:format(name), nil, true)
        if not result.success then
            error("unable to get env variable:\n" .. result.stderr)
        end
        value = result.stdout
    end

    if scope >= Scope.machine then
        if not ENV.is_windows then
            error("not implemented")
        end

        local result = ENV.execute(get_machine_template:format(name), nil, true)
        if not result.success then
            error("unable to get env variable:\n" .. result.stderr)
        end
        value = result.stdout
    end

    -- we just remove newlines since there should never be any in an env variable
    if value then
        value = value:gsub("\n", "")

        local variable = ENV.cache[name]
        if not variable then
            variable = {}
            ENV.cache[name] = variable
        end
        variable[scope] = value
    end

    return value
end

---@return { [string]: string }
function ENV.getenvs()
    return system.getenvs()
end

---@param name string
---@param value string?
---@param scope lua-config.environment.variable.scope
---@return boolean
function ENV.set(name, value, scope)
    if value == "" then
        value = nil
    end

    if scope == Scope.process then
        return system.setenv(name, value)
    elseif scope == Scope.user then
        if not ENV.is_windows then
            error("not implemented")
        end

        local command
        if value == nil then
            command = delete_user_template:format(name)
        else
            command = set_user_template:format(name, value)
        end

        if not ENV.execute(command, nil, true).success then
            return false
        end
    elseif scope == Scope.machine then
        if not ENV.is_windows then
            error("not implemented")
        end

        if not ENV.is_root then
            error("unable to set machine environment variables without elevated privileges")
        end

        local command
        if value == nil then
            command = delete_machine_template:format(name)
        else
            command = set_machine_template:format(name, value)
        end

        if not ENV.execute(command, nil, true).success then
            return false
        end
    end

    local variable = ENV.cache[name]
    if not variable then
        variable = {}
        ENV.cache[name] = variable
    end
    variable[scope] = value;

    return true
end

---@param name string
---@param scope lua-config.environment.variable.scope
---@return boolean
function ENV.unset(name, scope)
    if not ENV.set(name, nil, scope) then
        return false
    end

    return true
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@param before boolean | nil
---@param sep string | nil
---@return boolean
function ENV.add(name, value, scope, before, sep)
    sep = sep or ";"

    local items = utils.string.split(ENV.get(name, scope) or "", sep)
    for i, item in ipairs(items) do
        if item == value then
            if not before then
                return true
            end
            table.remove(items, i)
        end
    end

    if before then
        table.insert(items, 1, value)
    else
        table.insert(items, value)
    end

    return ENV.set(name, table.concat(items, sep), scope)
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@param sep string | nil
---@return boolean
function ENV.remove(name, value, scope, sep)
    sep = sep or ";"

    local items = utils.string.split(ENV.get(name, scope) or "")
    for i, item in ipairs(items) do
        if item == value then
            table.remove(items, i)
        end
    end

    return ENV.set(name, table.concat(items, sep), scope)
end

---@param name string | nil
function ENV.refresh(name)
    if name then
        local variable = ENV.cache[name]
        if not variable then
            return -- we lazy load environment variables
        end
        for scope in pairs(variable) do
            ENV.cache[name][scope] = ENV.get(name, scope, true)
        end
        return
    end
    for key in pairs(ENV.cache) do
        for scope in pairs(ENV.cache[key]) do
            ENV.cache[key][scope] = ENV.get(key, scope, true)
        end
    end
end

---@param varname string
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
os.getenv = function(varname)
    return ENV.get(varname)
end

return ENV
