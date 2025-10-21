---@class lua-config.path
local _path = {}

local home_path = (config.env.is_windows and (config.env.get("USERPROFILE"):gsub("\\", "/"))) or ("~")
local home_path_lenght = home_path:len()
---@param path string | nil
function _path.home(path)
    if not path then
        return home_path
    end

    if home_path:sub(home_path_lenght, home_path_lenght) ~= "/"
        and path:sub(1, 1) ~= "/" then
        path = "/" .. path
    end

    return home_path .. path
end

--- Resolves path and addes hostname if directory
--- is found with the host name as sub directory.
---@param path string
---@return string
function _path.add_hostname_if_found(path)
    if path:sub(path:len(), path:len()) ~= "/" then
        path = path .. "/"
    end

    local hostname_path = path .. config.env.hostname
    if lfs.exists(hostname_path)
        and lfs.attributes(hostname_path).mode == "directory" then
        return hostname_path
    end

    return path
end

--- Needs admin privilegies on windows use `create_junction` instead.
---@param path string
---@param target string
---@return boolean success
function _path.create_symlink(path, target)
    if config.env.is_windows then
        if not config.env.is_root then
            return false
        end
    end

    return lfs.link(target, path, true) == true
end

--- Will fallback to `create_symlink` on none windows machines.
---@param path string
---@param target string
---@return boolean success
function _path.create_junction(path, target)
    if not config.env.is_windows then
        return _path.create_symlink(path, target)
    end

    return config.env.execute("New-Item", { "-ItemType", "Junction", "-Path", "\"" .. path .. "\"", "-Target", "\"" .. target .. "\"" }, true).success
end

--- Will fallback to `create_symlink` on none windows machines.
---@param path string
---@param target string
---@return boolean success
function _path.create_shortcut(path, target)
    if not config.env.is_windows then
        return _path.create_symlink(path, target)
    end

    local command = '$shell = New-Object -ComObject WScript.Shell;$shortcut = $shell.CreateShortcut("%s");$shortcut.TargetPath = "%s";$shortcut.Save()'
    return config.env.execute(command:format(path, target), nil, true).success
end

return _path
