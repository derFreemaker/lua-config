---@class lua-config.environment
---@field package cache table<string, string | nil>
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
---@param command string
---@return boolean success
---@return integer exitcode
---@return string output
function env.execute(command)
    command:gsub("\"", "\\\"")

    local handle, err_msg
    if env.is_windows then
        handle, err_msg = io.popen("powershell -NoProfile -Command \"" .. command .. "\"")
    else
        handle, err_msg = io.popen("/bin/bash --noprofile --norc -c \"" .. command .. "\"")
    end
    if not handle then
        error("unable to open process handle:\n" .. err_msg)
    end

    local result = handle:read("*a")
    local success, _, code = handle:close()
    return (success == true) or false, code or 1, result
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
---@return string?
function env.get(name)
    local value = env.cache[name]
    if value then
        return value
    end

    value = org_getenv(name)
    env.cache[name] = value
    return value
end

---@alias lua-config.environment.variable.scope
---| "user"
---| "machine"

local set_user_template = "[System.Environment]::SetEnvironmentVariable(\"%s\", \"%s\", [System.EnvironmentVariableTarget]::User)"
local set_machine_template = "[System.Environment]::SetEnvironmentVariable(\"%s\", \"%s\", [System.EnvironmentVariableTarget]::Machine)"
---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope | nil
function env.set(name, value, scope)
    if not env.is_windows then
        error("'env.set(...)' is windows only should not be used on unix systems")
    end

    if scope == "user" then
        env.execute(set_user_template:format(name, value))
    elseif scope == "machine" then
        if not env.is_admin then
            error("unable to set machine environment variables without admin privileges")
        end

        env.execute(set_machine_template:format(name, value))
    end

    env.refresh(name)
end

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope | nil
---@param before boolean | nil
---@param sep string | nil
function env.add(name, value, scope, before, sep)
    if not env.is_windows then
        error("'env.add(...)' is windows only should not be used on unix systems")
    end

    sep = sep or ";"
    if before then
        value = value .. sep .. (env.get(name) or "")
    else
        value = (env.get(name) or "") .. sep .. value
    end

    env.set(name, value, scope)
end

---@param name string
---@param scope lua-config.environment.variable.scope | nil
function env.remove(name, scope)
    if not env.is_windows then
        error("'env.remove(...)' is windows only should not be used on unix systems")
    end

    env.set(name, "", scope)
    env.refresh(name)
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
