local lfs = lfs

---@class lua-config.path
local path = {}

--- Resolves path and addes hostname if directory is found 
---@param path string
---@return string
function path.resolve_path(path)
    if path:sub(path:len(), path:len()) ~= "/" then
        path = path .. "/"
    end

    local hostname_path = path .. config.env.hostname
    if lfs.exists(hostname_path) and lfs.attributes(hostname_path).mode == "directory" then
        return hostname_path
    end

    return path
end

---@param path string
---@param target string
---@return boolean success
function path.create_symlink(path, target)
    local command
    if config.env.is_windows then
        command = string.format('mklink /D "%s" "%s"', path, target)
    else
        command = string.format('ln -s "%s" "%s"', path, target)
    end

    local success = os.execute(command)
    return success == true
end

return path
