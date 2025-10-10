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
local _env = {
    os = lib.env.os,
    is_windows = system.windows,
    is_root = lib.env.is_root,

    hostname = lib.env.hostname,

    cache = {},
    scope = Scope,
}

---@class lua-config.execution

-- Will use 'powershell' on windows and '/bin/bash' on any other machine.
-- And will invoke with no profile to provide better consistency
---@param command string
---@param direct boolean | nil don't launch in 'powershell' or '/bin/bash'
---@return lua-config.execution handle
function _env.start_execute(command, direct)
    if direct then
        local handle, err_msg = io.popen(command)
        if not handle then
            error("unable to open process handle:\n" .. err_msg)
        end

        ---@diagnostic disable-next-line: cast-type-mismatch
        ---@cast handle lua-config.execution
        return handle
    end

    local handle, err_msg
    command = command
        :gsub([[\"]], [[\\"]])
        :gsub([["]], [[\"]])
    if _env.is_windows then
        command = "powershell -NoProfile -Command \"" .. command .. "\""
        handle, err_msg = io.popen(command)
    else
        command = "/bin/bash --noprofile --norc -c \"" .. command .. "\""
        handle, err_msg = io.popen(command)
    end

    if not handle then
        error("unable to open process handle:\n" .. err_msg)
    end

    ---@cast handle lua-config.execution
    return handle
end

---@param handle lua-config.execution
---@return boolean success
---@return integer exitcode
---@return string output
function _env.end_execute(handle)
    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast handle file*

    handle:seek("set", 0)
    local result = handle:read("a")
    local success, _, code = handle:close()
    return (success == true) or false, code or 1, result
end

-- Will use 'powershell' on windows and '/bin/bash' on any other machine.
-- And will invoke with no profile to provide better consistency
---@param command string
---@param direct boolean | nil
---@return boolean success
---@return integer exitcode
---@return string output
function _env.execute(command, direct)
    local handle = _env.start_execute(command, direct)
    return _env.end_execute(handle)
end

--- With 'nil' scope will return all data from user and machine
---@param name string
---@param scope lua-config.environment.variable.scope | nil
---@param ignore_cache boolean?
---@return string?
function _env.get(name, scope, ignore_cache)
    scope = scope or Scope.process
    ---@cast scope -string

    if not ignore_cache then
        local variable = _env.cache[name]
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
        if not _env.is_windows then
            error("not implemented")
        end

        local success, _, result = _env.execute(get_user_template:format(name))
        if not success then
            error("unable to get env variable:\n" .. result)
        end
        value = result
    end

    if scope >= Scope.machine then
        if not _env.is_windows then
            error("not implemented")
        end

        local success, _, result = _env.execute(get_machine_template:format(name))
        if not success then
            error("unable to get env variable:\n" .. result)
        end
        value = result
    end

    -- we just remove newlines since there should never be any in an env variable
    if value then
        value = value:gsub("\n", "")

        local variable = _env.cache[name]
        if not variable then
            variable = {}
            _env.cache[name] = variable
        end
        variable[scope] = value
    end

    return value
end

---@return { [string]: string }
function _env.getenvs()
    return system.getenvs()
end

---@param name string
---@param value string?
---@param scope lua-config.environment.variable.scope
---@return boolean
function _env.set(name, value, scope)
    if value == "" then
        value = nil
    end

    if scope == Scope.process then
        return system.setenv(name, value)
    elseif scope == Scope.user then
        if not _env.is_windows then
            error("not implemented")
        end

        local command
        if value == nil then
            command = delete_user_template:format(name)
        else
            command = set_user_template:format(name, value)
        end

        if not _env.execute(command) then
            return false
        end
    elseif scope == Scope.machine then
        if not _env.is_windows then
            error("not implemented")
        end

        if not _env.is_root then
            error("unable to set machine environment variables without elevated privileges")
        end

        local command
        if value == nil then
            command = delete_machine_template:format(name)
        else
            command = set_machine_template:format(name, value)
        end

        if not _env.execute(command) then
            return false
        end
    end

    local variable = _env.cache[name]
    if not variable then
        variable = {}
        _env.cache[name] = variable
    end
    variable[scope] = value;

    return true
end

---@param name string
---@param scope lua-config.environment.variable.scope
---@return boolean
function _env.unset(name, scope)
    if not _env.set(name, nil, scope) then
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
function _env.add(name, value, scope, before, sep)
    sep = sep or ";"

    local items = utils.string.split(_env.get(name, scope) or "", sep)
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

    return _env.set(name, table.concat(items, sep), scope)
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@param sep string | nil
---@return boolean
function _env.remove(name, value, scope, sep)
    sep = sep or ";"

    local items = utils.string.split(_env.get(name, scope) or "")
    for i, item in ipairs(items) do
        if item == value then
            table.remove(items, i)
        end
    end

    return _env.set(name, table.concat(items, sep), scope)
end

---@param name string | nil
function _env.refresh(name)
    if name then
        local variable = _env.cache[name]
        if not variable then
            return -- we lazy load environment variables
        end
        for scope in pairs(variable) do
            _env.cache[name][scope] = _env.get(name, scope, true)
        end
        return
    end
    for key in pairs(_env.cache) do
        for scope in pairs(_env.cache[key]) do
            _env.cache[key][scope] = _env.get(key, scope, true)
        end
    end
end

---@param varname string
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
os.getenv = function(varname)
    return _env.get(varname)
end

return _env
