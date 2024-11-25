---@class lua-config.environment
---@field package cache table<string, string>
---
---@field os "windows" | "linux"
---@field is_windows boolean
---@field is_admin boolean
---
---@field hostname string
local env = {
    cache = {},
}

-- Will use 'powershell' on windows and '/bin/bash' on any other machine.
-- And will invoke with no profile to provide better consistency
---@param command string
---@param direct boolean | nil
---@return file* handle
function env.start_execute(command, direct)
    local handle, err_msg
    if direct then
        handle, err_msg = io.popen(command)
    elseif env.is_windows then
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
function env.end_execute(handle)
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
function env.execute(command, direct)
    local handle = env.start_execute(command, direct)
    return env.end_execute(handle)
end

if package.config:sub(1, 1) == '\\' then
    env.os = "windows"
else
    env.os = "linux"
end
env.is_windows = env.os == "windows"

if env.os == "windows" then
    env.is_admin = env.execute("net session 2>&1")
else
    env.is_admin = env.execute("sudo -n true 2>&1")
end
function env.check_admin()
    if env.is_admin then
        return
    end

    print("admin privileges needed")
    os.exit(1)
end

if env.is_windows then
    env.hostname = os.getenv("COMPUTERNAME"):lower()
else
    local handle = io.popen("/bin/hostname", "r")
    if not handle then
        error("unable to get hostname!")
    end

    env.hostname = handle:read("a")
    handle:close()
end

local org_getenv = os.getenv
---@param name string
---@return string
function env.get(name)
    local value = env.cache[name]
    if value then
        return value
    end

    value = org_getenv(name) or ""
    env.cache[name] = value
    return value
end

---@alias lua-config.environment.variable.scope
---| "user"
---| "machine"

local set_user_template =
"[System.Environment]::SetEnvironmentVariable(\"%s\", \"%s\", [System.EnvironmentVariableTarget]::User)"
local set_machine_template =
"[System.Environment]::SetEnvironmentVariable(\"%s\", \"%s\", [System.EnvironmentVariableTarget]::Machine)"
---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@return boolean
function env.set(name, value, scope)
    if not env.is_windows then
        error("'env.set(...)' is windows only")
    end

    if scope == "user" then
        if not env.execute(set_user_template:format(name, value)) then
            return false
        end
    elseif scope == "machine" then
        if not env.is_admin then
            error("unable to set machine environment variables without admin privileges")
        end

        if not env.execute(set_machine_template:format(name, value)) then
            return false
        end
    end

    env.cache[name] = value
    return true
end

---@param name string
---@param scope lua-config.environment.variable.scope
---@return boolean
function env.unset(name, scope)
    if not env.is_windows then
        error("'env.remove(...)' is windows only")
    end

    if not env.set(name, "", scope) then
        return false
    end
    env.cache[name] = ""

    return true
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@param before boolean | nil
---@param sep string | nil
---@return boolean
function env.add(name, value, scope, before, sep)
    if not env.is_windows then
        error("'env.add(...)' is windows only")
    end
    sep = sep or ";"

    if before then
        value = value .. sep .. (env.get(name) or "")
    else
        value = (env.get(name) or "") .. sep .. value
    end

    return env.set(name, value, scope)
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope
---@return boolean
function env.remove(name, value, scope)
    if not env.is_windows then
        error("'env.remove(...)' is windows only")
    end

    local cur_value = env.get(name)
    local start_pos, end_pos = cur_value:find(value, nil, true)
    if not start_pos or not end_pos then
        return false
    end

    value = value:sub(0, start_pos - 1) .. value:sub(end_pos + 1)

    if not env.set(name, value, scope) then
        return false
    end

    env.cache[name] = value
    return true
end

---@param name string | nil
function env.refresh(name)
    if name then
        env.cache[name] = org_getenv(name)
        return
    end
    for key in pairs(env.cache) do
        env.cache[key] = org_getenv(key)
    end
end

return env
