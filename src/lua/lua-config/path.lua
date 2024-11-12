local lfs = lfs

---@class lua-config.path
---@field home string
local _path = {
    home = (config.env.is_windows and (config.env.get("USERPROFILE"):gsub("\\", "/") .. "/")) or ("~/")
}

--- Resolves path and addes hostname if directory is found 
---@param path string
---@return string
function _path.add_hostname_if_found(path)
    if path:sub(path:len(), path:len()) ~= "/" then
        path = path .. "/"
    end

    local hostname_path = path .. config.env.hostname
    if lfs.exists(hostname_path) and lfs.attributes(hostname_path).mode == "directory" then
        return hostname_path
    end

    return path
end

--- Needs admin privilegies on windows use `create_junction` instead.
---@param path string
---@param target string
---@return boolean success
function _path.create_symlink(path, target)
    local command
    if config.env.is_windows then
        if not config.env.is_admin then
            return false
        end

        command = string.format('mklink /D "%s" "%s"', path, target)
    else
        command = string.format('ln -s "%s" "%s"', path, target)
    end

    local success = config.env.execute(command)
    return success == true
end

--- Will fallback to `create_symlink` on none windows machines.
---@param path string
---@param target string
---@return boolean success
function _path.create_junction(path, target)
    if config.env.is_windows then
        local success = config.env.execute(string.format('mklink /J "%s" "%s"', path, target))
        return success
    else
        return _path.create_symlink(path, target)
    end
end

return _path
