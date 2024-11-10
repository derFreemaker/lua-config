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

---@param command string
---@return boolean
---@return integer
---@return string
function env.execute(command)
    local handle, err_msg = io.popen(command, "r")
    if not handle then
        error("unable to open process handle:\n" .. err_msg)
    end

    local result = handle:read("*a")
    local success, _, code = handle:close()
    return success or false, code or 1, result
end

if package.config:sub(1, 1) == '\\' then
    env.os = "windows"
else
    -- Attempt to detect macOS
    local _, _, result = env.execute("uname")

    if result == "Darwin" then
        env.os = "macOS"
    else
        env.os = "linux"
    end
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

    print("adming privileges needed")
    os.exit(1)
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

function env.refresh()
    for key in pairs(env.cache) do
        env.cache[key] = org_getenv(key)
    end
end

--- This assumes powershell can be reached with 'pwsh'
---@param command string
---@param pwsh_path string | nil
---@return boolean
---@return integer
---@return string
function env.execute_in_pwsh(command, pwsh_path)
    pwsh_path = pwsh_path or "pwsh"

    command:gsub("\"", "\\\"")
    return env.execute("pwsh -Command \"" .. command .. "\"")
end

return env
