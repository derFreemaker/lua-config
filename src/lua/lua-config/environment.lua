local org_getenv = os.getenv

---@alias lua-config.environment.variable.scope
---| "user"
---| "machine"

---@class lua-config.environment
---@field package cache table<string, table<"all" | lua-config.environment.variable.scope, string>>
---
---@field os "windows" | "unix"
---@field is_windows boolean
---@field is_admin boolean
---
---@field hostname string
local _env = {
    cache = {},
}

-- Will use 'powershell' on windows and '/bin/bash' on any other machine.
-- And will invoke with no profile to provide better consistency
---@param command string
---@param direct boolean | nil
---@return file* handle
function _env.start_execute(command, direct)
    local handle, err_msg
    if direct then
        handle, err_msg = io.popen(command)
    elseif _env.is_windows then
        command = command:gsub("\"", "\\\"")
        handle, err_msg = io.popen("powershell -NoProfile -Command \"" .. command .. "\"")
    else
        command = command:gsub("\"", "\\\"")
        handle, err_msg = io.popen("/bin/bash --noprofile --norc -c \"" .. command .. "\"")
    end
    if not handle then
        error("unable to open process handle:\n" .. err_msg)
    end

    return handle
end

---@param handle file*
---@return boolean success
---@return integer exitcode
---@return string output
function _env.end_execute(handle)
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

if package.config:sub(1, 1) == '\\' then
    _env.os = "windows"
else
    _env.os = "unix"
end
_env.is_windows = _env.os == "windows"

if _env.os == "windows" then
    _env.is_admin = _env.execute("net session 2>&1")
else
    _env.is_admin = _env.execute("sudo -n true 2>&1")
end
function _env.check_admin()
    if _env.is_admin then
        return
    end

    print("admin privileges needed")
    os.exit(1)
end

if _env.is_windows then
    _env.hostname = org_getenv("COMPUTERNAME"):lower()
else
    local handle = io.popen("/bin/hostname", "r")
    if not handle then
        error("unable to get hostname!")
    end

    _env.hostname = handle:read("a")
    handle:close()
end

local get_user_template =
"[System.Environment]::GetEnvironmentVariable(\"%s\", [System.EnvironmentVariableTarget]::User)"
local get_machine_template =
"[System.Environment]::GetEnvironmentVariable(\"%s\", [System.EnvironmentVariableTarget]::Machine)"

--- With 'nil' scope will return all data from user and machine
---@param name string
---@param scope lua-config.environment.variable.scope | "all" | nil
---@return string
function _env.get(name, scope)
    scope = scope or "all"
    ---@cast scope -string

    local variable = _env.cache[name]
    if variable and variable[scope] then
        return variable[scope]
    end

    ---@type string
    local value
    if scope == "all" then
        value = org_getenv(name) or ""
    elseif scope == "user" then
        local success, _, result = _env.execute(get_user_template:format(name))
        if not success then
            error("unable to get env variable:\n" .. result)
        end
        value = result
    elseif scope == "machine" then
        local success, _, result = _env.execute(get_machine_template:format(name))
        if not success then
            error("unable to get env variable:\n" .. result)
        end
        value = result
    end

    if not variable then
        variable = {}
        _env.cache[name] = variable
    end
    variable[scope] = value

    return value
end

local set_user_template =
"[System.Environment]::SetEnvironmentVariable(\"%s\", \"%s\", [System.EnvironmentVariableTarget]::User)"
local set_machine_template =
"[System.Environment]::SetEnvironmentVariable(\"%s\", \"%s\", [System.EnvironmentVariableTarget]::Machine)"
---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@return boolean
function _env.set(name, value, scope)
    if not _env.is_windows then
        error("'env.set(...)' is windows only")
    end

    if scope == "user" then
        if not _env.execute(set_user_template:format(name, value)) then
            return false
        end
    elseif scope == "machine" then
        if not _env.is_admin then
            error("unable to set machine environment variables without elevated privileges")
        end

        if not _env.execute(set_machine_template:format(name, value)) then
            return false
        end
    end

    _env.refresh(name)
    return true
end

---@param name string
---@param scope lua-config.environment.variable.scope
---@return boolean
function _env.unset(name, scope)
    if not _env.is_windows then
        error("'env.remove(...)' is windows only")
    end

    if not _env.set(name, "", scope) then
        return false
    end
    _env.cache[name][scope] = ""

    return true
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@param before boolean | nil
---@param sep string | nil
---@return boolean
function _env.add(name, value, scope, before, sep)
    if not _env.is_windows then
        error("'env.add(...)' is windows only")
    end
    sep = sep or ";"

    if before then
        value = value .. sep .. (_env.get(name, scope) or "")
    else
        value = (_env.get(name, scope) or "") .. sep .. value
    end

    return _env.set(name, value, scope)
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@return boolean
function _env.remove(name, value, scope)
    if not _env.is_windows then
        error("'env.remove(...)' is windows only")
    end

    local cur_value = _env.get(name, scope)
    local start_pos, end_pos = cur_value:find(value, nil, true)
    if not start_pos or not end_pos then
        return false
    end

    value = value:sub(0, start_pos - 1) .. value:sub(end_pos + 1)

    return _env.set(name, value, scope)
end

---@param name string | nil
function _env.refresh(name)
    if name then
        for scope in pairs(_env.cache[name]) do
            _env.cache[name][scope] = _env.get(name, scope)
        end
        return
    end
    for key in pairs(_env.cache) do
        for scope in pairs(_env.cache[key]) do
            _env.cache[key][scope] = _env.get(key, scope)
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
