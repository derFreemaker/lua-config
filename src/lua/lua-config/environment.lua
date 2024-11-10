---@class lua-config.environment
---@field package cache table<string, string>
---
---@field os "windows" | "linux" | "macOS"
---@field is_windows boolean
---@field is_admin boolean
---
---@field hostname string
local env = {
    cache = {},
}

if package.config:sub(1, 1) == '\\' then
    env.os = "windows"
else
    -- Attempt to detect macOS

    local f = io.popen("uname")
    if not f then
        error("unable to open io.popen!")
    end

    local uname = f:read("*l")
    f:close()

    if uname == "Darwin" then
        env.os = "macOS"
    else
        env.os = "linux"
    end
end
env.is_windows = env.os == "windows"

if env.os == "windows" then
    env.is_admin = os.execute("net session >nul 2>&1") == true
else
    env.is_admin = os.execute("sudo -n true > /dev/null 2>&1") == true
end

if env.is_windows then
    env.hostname = os.getenv("COMPUTERNAME"):lower()
else
    local handle = io.popen("/bin/hostname", "r")
    if not handle then
        error("unable to get hostname!")
    end

    env.hostname = handle:read("l")
    handle:close()
end

local org_getenv = os.getenv
---@param name string
---@return string?
function env.get(name)
    ---@type string?
    local value = env.cache[name]
    if value then
        return value
    end

    value = org_getenv(name)
    env.cache[name] = value
    return value
end

---@alias lua-config.environment.variable.scope
---|>"lua"
---| "user"
---| "machine"

---@param name string
---@param value string
---@param scope lua-config.environment.variable.scope?
function env.set(name, value, scope)
    scope = scope or "lua"

    if scope == "lua" then
        env.cache[name] = value
    elseif scope == "user" then
        env.cache[name] = value

        if env.is_windows then
            os.execute('setx "' .. name .. '" "' .. value .. '"')
        else
            local user_profile = os.getenv("HOME") .. "/.bashrc"
            os.execute("echo 'export " .. name .. "=\"" .. value .. "\"' >> " .. user_profile)
            os.execute("source " .. user_profile)
        end
    elseif scope == "machine" then
        env.cache[name] = value

        if not env.is_admin then
            error("unable to set machine environment variables without admin privileges")
        end

        if env.is_windows then
            os.execute('setx "' .. name .. '" "' .. value .. '"/M')
        else
            os.execute("echo '" .. name .. "=\"" .. value .. "\"' | sudo tee -a /etc/environment")
            os.execute("source /etc/environment")
        end
    else
        error("Invalid scope. Use 'process', 'user', or 'machine'.")
    end
end

---@param command string
---@return string
function env.execute(command)
    local handle, err_msg = io.popen(command)
    if not handle then
        error("unable to open process handle:\n" .. err_msg)
    end

    local result = handle:read("*a")
    handle:close()
    return result
end

return env
