---@meta _

---@class lua-config.lib
---@field fs lua-config.lib.fs
---@field env lua-config.lib.env
local LuaConfig = {}

---@class lua-config.lib.execution
local Execution = {}

---@class lua-config.lib.execution.result
---@field success boolean
---@field exitcode integer
---@field stdout string
---@field stderr string

---@return lua-config.lib.execution.result
function Execution:wait()
end

---@param path string
---@param args string[]
---@return lua-config.lib.execution
function LuaConfig:execute(path, args)
end

---@class lua-config.lib.fs
local Fs = {}

---@param path string
---@return boolean
function Fs:chdir(path)
end

---@return string?
function Fs:currentdir()
end

---@class lua-config.lib.fs.attributes
local Attributes = {}

--- A number that the system uses to point to the file metadata. This
--- number is not guaranteed to be unique across time, as some file
--- systems may reuse an inode after its file has been deleted. Some
--- systems may change the inode of a file over time.
---
--- On Linux, the inode is a structure that stores the metadata, and
--- the inode _number_ is what you see here: the index number of the
--- inode.
---
--- The FileIndex on Windows is similar. It is a number for a file that
--- is unique to each filesystem.
---@type integer
Attributes.inode = 0

---@type integer
Attributes.size = 0

--- This is available on POSIX systems and is always 0 otherwise.
---@type integer
Attributes.mode = 0

---@alias lua-config.lib.fs.attributes.kind
---|"block_device"
---|"character_device"
---|"directory"
---|"named_pipe"
---|"sym_link"
---|"file"
---|"unix_domain_socket"
---|"whiteout"
---|"door"
---|"event_port"
---|"unknown"

---@type lua-config.lib.fs.attributes.kind
Attributes.kind = "unknown"

--- Last access time in milliseconds, relative to UTC 1970-01-01.
---@type number
Attributes.access_time = 0

--- Last modification time in milliseconds, relative to UTC 1970-01-01.
---@type number
Attributes.modified_time = 0

--- Last status/metadata change time in milliseconds, relative to UTC 1970-01-01.
---@type number
Attributes.created_time = 0

---@param path string
---@return lua-config.lib.fs.attributes?
function Fs:attributes(path)
end

---@class lua-config.lib.fs.link_attributes : lua-config.lib.fs.attributes
local LinkAttributes = {}

--- the target of the symlink
---@type string
LinkAttributes.target = ""

--- get information about a symlink
---@param path string
---@return lua-config.lib.fs.link_attributes?
function Fs:link_attributes(path)
end

---@param path string
---@return boolean
function Fs:exists(path)
end

---@class lua-config.lib.fs.dir
local Dir = {}

function Dir:close()
end

function Dir:next()
end

---@param path string
---@return fun() : string?
---@return lua-config.lib.fs.dir
function Fs:dir(path)
end

---@param path string
---@return boolean
function Fs:mkdir(path)
end

---@param path string
---@return boolean
function Fs:rmdir(path)
end

---@param path string
---@param target string
---@param is_directory boolean
---@return boolean
function Fs:create_symlink(path, target, is_directory)
end

---@class lua-config.lib.env
---@field os string
---@field is_windows boolean
---@field is_root boolean
---@field hostname string
local Env = {}

---@param name string
---@return string?
function Env:get(name)
end

---@param name string
---@param value string?
---@return boolean
function Env:set(name, value)
end
