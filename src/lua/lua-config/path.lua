local lfs = lfs

---@class lua-config.path
local path = {}

--- Resolves path and addes hostname if directory is found 
---@param path_str string
---@return string
function path.add_hostname_if_found(path_str)
    if path_str:sub(path_str:len(), path_str:len()) ~= "/" then
        path_str = path_str .. "/"
    end

    local hostname_path = path_str .. config.env.hostname
    if lfs.exists(hostname_path) and lfs.attributes(hostname_path).mode == "directory" then
        return hostname_path
    end

    return path_str
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
