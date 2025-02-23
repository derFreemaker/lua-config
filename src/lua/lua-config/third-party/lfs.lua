---@type lfs
local lfs = require("lfs")

function lfs.exists(path)
    return lfs.attributes(path, "mode") ~= nil
end

return lfs
