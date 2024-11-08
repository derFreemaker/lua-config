---@type "windows" | "linux" | "macOS"
local os_name
if package.config:sub(1, 1) == '\\' then
    os_name = "windows"
else
    -- Attempt to detect macOS

    local f = io.popen("uname")
    if not f then
        print("unable to open io.popen!")
        os.exit(1)
    end

    local uname = f:read("*l")
    f:close()

    if uname == "Darwin" then
        os_name = "macOS"
    else
        os_name = "linux"
    end
end

local is_admin = false
if os_name == "windows" then
    is_admin = os.execute("net session >nul 2>&1") == true
else
    is_admin = os.execute("sudo -n true > /dev/null 2>&1") == true
end

local function get_hostname()
    local handle
    if os_name == "windows" then
        return os.getenv("COMPUTERNAME")
    else
        handle = io.popen("/bin/hostname", "r")
    end
    if not handle then
        error("unable to get hostname!")
    end

    local hostname = handle:read("*a") or ""
    handle:close()

    return hostname:gsub("\n$", "")
end

---@class lua-config.environment
---@field private cache table<string, string>
env = {
    cache = {},
    os = os_name,
    is_windows = os_name == "windows",
    is_admin = is_admin,

    hostname = get_hostname()
}

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

os.getenv = env.get

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
