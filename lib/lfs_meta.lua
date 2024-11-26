---@meta

---@class lfs
lfs = {}

---@class lfs.attributes
---@field dev integer on Unix systems, this represents the device that the inode resides on. On Windows systems, represents the drive number of the disk containing the file
---@field ino integer on Unix systems, this represents the inode number. On Windows systems this has no meaning
---@field mode "file" | "directory" | "link" | "socket" | "named pipe" | "char device" | "block device" | "other" string representing the associated protection mode
---@field nlink integer number of hard links to the file
---@field uid integer user-id of owner (Unix only, always 0 on Windows)
---@field gid integer group-id of owner (Unix only, always 0 on Windows)
---@field rdev integer on Unix systems, represents the device type, for special file inodes. On Windows systems represents the same as dev
---@field access integer time of last access
---@field modification integer time of last data modification
---@field change integer time of last file status change
---@field size integer file size, in bytes
---@field permissions string file permissions
---@field blocks integer block allocated for file (Unix only)
---@field blksize integer optimal file system I/O blocksize (Unix only)

--- Returns a table with the file attributes corresponding to filepath (or nil followed by an error message and a system-dependent error code in case of error).
--- If the second optional argument is given and is a string, then only the value of the named attribute is returned (this use is equivalent to lfs.attributes(filepath)[request_name],
--- but the table is not created and only one attribute is retrieved from the O.S.). if a table is passed as the second argument,
--- it (result_table) is filled with attributes and returned instead of a new table. The attributes are described as follows;
--- attribute mode is a string, all the others are numbers, and the time related attributes use the same time reference of os.time.
--- This function uses stat internally thus if the given filepath is a symbolic link, it is followed (if it points to another link the chain is followed recursively)
--- and the information is about the file it refers to. To obtain information about the link itself, see function lfs.symlinkattributes.
---@param path string
---@return lfs.attributes | nil
---@return string | nil
---@return integer | nil
function lfs.attributes(path) end

---@param path string
---@param request_name string
---@return any
function lfs.attributes(path, request_name) end

---@param path string
---@param result_table table
function lfs.attributes(path, result_table) end


---@param path string
---@return boolean
function lfs.exists(path) end


--- Changes the current working directory to the given path.
--- Returns true in case of success or nil plus an error string.
---@param path string
---@return boolean | nil
---@return string | nil
function lfs.chdir(path) end


---@class lfs.lock
local lock = {}

function lock:free() end

--- Creates a lockfile (called lockfile.lfs) in path if it does not exist and returns the lock.
--- If the lock already exists checks if it's stale, using the second parameter
--- (default for the second parameter is INT_MAX, which in practice means the lock will never be stale. To free the the lock call lock:free().
--- In case of any errors it returns nil and the error message. In particular,
--- if the lock exists and is not stale it returns the "File exists" message.
---@param path string
---@param seconds_stale integer | nil
---@return lfs.lock | nil lock
---@return string err_msg
function lfs.lock_dir(path, seconds_stale) end

--- Returns a string with the current working directory or nil plus an error string.
---@return string | nil path
---@return string | nil err_msg
function lfs.currentdir() end


---@class lfs.dir
local dir = {}

---@return string
function dir:next() end

function dir:close() end

--- Lua iterator over the entries of a given directory. Each time the iterator is called with dir_obj it returns a directory entry's name as a string,
--- or nil if there are no more entries. You can also iterate by calling dir_obj:next(), and explicitly close the directory before the iteration finished with dir_obj:close().
--- Raises an error if path is not a directory.
---@param path string
---@return fun(dir: lfs.dir) : string
---@return lfs.dir
function lfs.dir(path) end


--- Locks a file or a part of it. This function works on open files; the file handle should be specified as the first argument.
--- The string mode could be either r (for a read/shared lock) or w (for a write/exclusive lock).
--- The optional arguments start and length can be used to specify a starting point and its length; both should be numbers.
--- Returns true if the operation was successful; in case of error, it returns nil plus an error string.
---@param file_handle file*
---@param mode "r" | "w"
---@param start integer | nil
---@param lenght integer | nil
---@return boolean | nil
---@return string | nil
function lfs.lock(file_handle, mode, start, lenght) end


--- Creates a link. The first argument is the object to link to and the second is the name of the link.
--- If the optional third argument is true, the link will by a symbolic link (by default, a hard link is created).
---@param target string
---@param path string
---@param symlink boolean | nil
function lfs.link(target, path, symlink) end


--- Creates a new directory. The argument is the name of the new directory.
--- Returns true in case of success or nil, an error message and a system-dependent error code in case of error.
---@param path string
---@return boolean | nil
---@return string | nil
---@return integer | nil
function lfs.mkdir(path) end


--- Removes an existing directory. The argument is the name of the directory.
--- Returns true in case of success or nil, an error message and a system-dependent error code in case of error.
---@param path string
---@return boolean | nil
---@return string | nil
---@return integer | nil
function lfs.rmdir(path) end


--- Sets the writing mode for a file. The mode string can be either "binary" or "text".
--- Returns true followed the previous mode string for the file, or nil followed by an error string in case of errors.
--- On non-Windows platforms, where the two modes are identical, setting the mode has no effect, and the mode is always returned as binary.
---@param file file*
---@param mode "binary" | "text"
---@return boolean | nil
---@return string | nil
function lfs.setmode(file, mode) end


--- Identical to lfs.attributes except that it obtains information about the link itself (not the file it refers to).
--- It also adds a target field, containing the file name that the symlink points to. On Windows this function does not yet support links,
--- and is identical to lfs.attributes.
---@param path string
---@return lfs.attributes | nil
---@return string | nil
---@return integer | nil
function lfs.symlinkattributes(path) end

---@param path string
---@param request_name string
---@return any
function lfs.symlinkattributes(path, request_name) end

---@param path string
---@param result_table table
function lfs.symlinkattributes(path, result_table) end


--- Set access and modification times of a file. This function is a bind to utime function. The first argument is the filename,
--- the second argument (atime) is the access time, and the third argument (mtime) is the modification time.
--- Both times are provided in seconds (which should be generated with Lua standard function os.time). If the modification time is omitted,
--- the access time provided is used; if both times are omitted, the current time is used.
--- Returns true in case of success or nil, an error message and a system-dependent error code in case of error.
---@param path string
---@param atime integer | nil
---@param mtime integer | nil
---@return boolean | nil
---@return string | nil
---@return integer | nil
function lfs.touch(path, atime, mtime) end


--- Unlocks a file or a part of it. This function works on open files; the file handle should be specified as the first argument.
--- The optional arguments start and length can be used to specify a starting point and its length; both should be numbers.
--- Returns true if the operation was successful; in case of error, it returns nil plus an error string.
---@param file_handle file*
---@param start integer | nil
---@param length integer | nil
---@return boolean | nil
---@return string | nil
function lfs.unlock(file_handle, start, length) end
