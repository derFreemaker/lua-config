---@meta _

---@class luasystem.bitflags
---@field [integer] boolean
local bitflags = {}

--- Checks if all the flags in the given subset are set.
--- If the flags to check has a value 0, it will always return false.
--- So if there are flags that are unsupported on a platform,
--- they can be set to 0 and the has_all_of function will
--- return false if the flags are checked.
---@param subset luasystem.bitflags
---@return boolean
function bitflags:has_all_of(subset)
end

--- Checks if any of the flags in the given subset are set.
--- If the flags to check has a value 0, it will always return false.
--- So if there are flags that are unsupported on a platform,
--- they can be set to 0 and the has_any_of function will
--- return false if the flags are checked.
---@param subset luasystem.bitflags
---@return boolean
function bitflags:has_any_of(subset)
end

---@return integer
function bitflags:value()
end

---@class luasystem
---@field windows boolean
local system = {}

--- Creates a new bitflag object from the given value.
---@param value integer
---@return luasystem.bitflags
function system.bitflag(value)
end

---@param name string
---@return string?
function system.getenv(name)
end

---@return { [string]: string }
function system.getenvs()
end

--- NOTE:
---
--- Windows has multiple copies of environment variables.
--- For this reason, the setenv function will not work with Lua's os.getenv on Windows.
--- If you want to use it then consider patching os.getenv with
--- the implementation of system.getenv.
---@param name string
---@param value string?
---@return boolean
function system.setenv(name, value)
end

--- Generate random bytes.
--- This uses BCryptGenRandom() on Windows,
--- getrandom() on Linux, arc4random_buf on BSD,
--- and /dev/urandom on other platforms.
--- It will return the requested number of bytes,
--- or an error, never a partial resul
---@param length integer?
---@return string? bytes
---@return string? err
function system.random(length)
end

---@param file file*
---@return boolean
function system.isatty(file)
end

--- on error returns nil and error message
---@return integer?
---@return integer | string
function system.termsize()
end

--- Gets console flags (Windows).
--- The CIF_ and COF_ constants are available on the module table.
--- Where CIF are the input flags (for use with io.stdin) and
--- COF are the output flags (for use with io.stdout/io.stderr).
---
--- NOTE:
---
--- see [setconsolemode documentation](https://learn.microsoft.com/en-us/windows/console/setconsolemode)
--- for more information on the flags
---@param file file*
---@return luasystem.bitflags?
---@return string? err
function system.getconsoleflags(file)
end

--- Debug function for console flags (Windows). Pretty prints the current flags set for the handle.
---@param file file*
function system.listconsoleflags(file)
end

--- Sets the console flags (Windows).
--- The CIF_ and COF_ constants are available on the module table.
--- Where CIF are the input flags (for use with io.stdin) and
--- COF are the output flags (for use with io.stdout/io.stderr).
---
--- To see flag status and constant names check `listconsoleflags`.
---
--- NOTE:
---
--- see [setconsolemode documentation](https://learn.microsoft.com/en-us/windows/console/setconsolemode)
--- for more information on the flags
---@param file file*
---@param flags luasystem.bitflags
---@return boolean?
---@return string? err
function system.setconsoleflags(file, flags)
end

--- Creates new file descriptions for stdout and stderr.
--- Even if the file descriptors are unique,
--- they still might point to the same file description,
--- and hence share settings like O_NONBLOCK.
--- This means that if one of them is set to non-blocking,
--- the other will be as well. This can lead to unexpected behavior.
---
--- This function is used to detach stdout and stderr from the original file descriptions,
--- and create new file descriptions for them.
--- This allows independent control of flags (e.g., O_NONBLOCK) on stdout and stderr,
--- avoiding shared side effects.
---
--- Does not modify stdin (fd 0), and does nothing on Windows.
---
--- throws an error on failure
---@return boolean
function system.detachfds()
end

--- Gets non-blocking mode status for a file (Posix).
---
--- Always returns false on Windows
---@param file file*
---@return boolean?
---@return string? err
---@return integer? errnum
function system.getnonblock(file)
end

--- Debug function for terminal flags (Posix).
--- Pretty prints the current flags set for the handle.
---@param file file*
function system.listtermflags(file)
end

--- Enables or disables non-blocking mode for a file (Posix).
--- Check `detachfds` in case there are shared file descriptions.
---@param file file*
---@param make_non_block boolean
---@return boolean?
---@return string? err
---@return integer? errnum
function system.setnonblock(file, make_non_block)
end

---@class luasystem.termios
---@field iflag luasystem.bitflags
---@field oflag luasystem.bitflags
---@field lflag luasystem.bitflags
---@field cflag luasystem.bitflags
---@field ispeed integer
---@field ospeed integer
---@field cc table

--- Get termios state (Posix). The terminal attributes is a table with the following fields:
---
--- iflag input flags
--- oflag output flags
--- lflag local flags
--- cflag control flags
--- ispeed input speed
--- ospeed output speed
--- cc control characters
---
--- On Windows the bitflags are all 0, and the cc table is empty.
---@param file file*
---@return luasystem.termios?
---@return string? err
---@return integer? errnum
function system.tcgetattr(file)
end

---@class luasystem.termios.tcsetattr
---@field iflag luasystem.bitflags?
---@field oflag luasystem.bitflags?
---@field lflag luasystem.bitflags?

--- Set termios state (Posix). This function will set the flags as given.
---
--- The I_, O_, and L_ constants are available on the module table.
--- They are the respective flags for the iflags, oflags, and lflags bitmasks.
---
--- To see flag status and constant names check listtermflags. For their meaning check the manpage.
---
--- Note:
---
--- only iflag, oflag, and lflag are supported at the moment. The other fields are ignored.
---@param file file*
---@param actions integer one of TCSANOW, TCSADRAIN, TCSAFLUSH
---@param termios luasystem.termios.tcsetattr
---@return boolean?
---@return string? err
---@return integer? errnum
function system.tcsetattr(file, actions, termios)
end

--- Reads a key from the console non-blocking.
--- This function should not be called directly,
--- but through the system.readkey or system.readansi functions.
--- It will return the next byte from the input stream, or `nil` if no key was pressed.
---
--- On Posix, io.stdin must be set to non-blocking mode using setnonblock
--- and canonical mode must be turned off using tcsetattr,
--- before calling this function. Otherwise it will block.
--- No conversions are done on Posix, so the byte read is returned as-is.
---
--- On Windows this reads a wide character and converts it to UTF-8.
--- Multi-byte sequences will be buffered internally
--- and returned one byte at a time.
---@return integer?
---@return string? err
---@return integer? errnum (on posix)
function system._readkey()
end

--- Reads a single key, if it is the start of ansi escape sequence then
--- it reads the full sequence. The key can be a multi-byte string
--- in case of multibyte UTF-8 character. This function uses system.readkey,
--- and hence fsleep to wait until either a key is available or the timeout is reached.
--- It returns immediately if a key is available or if timeout is less than or equal to 0.
--- In case of an ANSI sequence, it will return the full sequence as a string.
---@param timeout number
---@param fsleep fun(seconds: number)? default: system.sleep
---@return string? cahr the character that was received (can be multi-byte), or a complete ANSI sequence
---@return "ctrl" | "char" | "ansi" | string | "timeout" type_of_input "ctrl" for 0-31 and 127 bytes, "char" for other UTF-8 characters, "ansi" for an ANSI sequence
---@return string? partial_result in case of an error while reading a sequence, the sequence so far. The function retains its own internal buffer, so on the next call the incomplete buffer is used to complete the sequence.
function system.readansi(timeout, fsleep)
end

--- Reads a single byte from the console, with a timeout.
--- This function uses fsleep to wait until either a byte is available
--- or the timeout is reached. The sleep period is exponentially backing off,
--- starting at 0.0125 seconds, with a maximum of 0.1 seconds.
--- It returns immediately if a byte is available
--- or if timeout is less than or equal to 0.
---
--- Using system.readansi is preferred over this function.
--- Since this function can leave stray/invalid byte-sequences in the input buffer,
--- while system.readansi reads full ANSI and UTF8 sequences.
---@param timeout number
---@param fsleep fun(seconds: number)? default: system.sleep
---@return string? byte
---@return string? | "timeout" err
function system.readkey(timeout, fsleep)
end

--- UTF8 codepage. To be used with `system.setconsoleoutputcp` and `system.setconsolecp`.
---@type integer
system.CODEPAGE_UTF8 = 65001

--- Gets the current console code page (Windows).
---@return integer current_code_page (always `65001` on Posix systems)
function system.getconsolecp()
end

--- Gets the current console output code page (Windows).
---@return integer current_code_page (always `65001` on Posix systems)
function system.getconsoleoutputcp()
end

--- Sets the current console code page (Windows).
---@param cp integer
---@return boolean success (always `true` on Posix systems)
function system.setconsolecp(cp)
end

--- Sets the current console output code page (Windows).
---@param cp integer
---@return boolean success (always `true` on Posix systems)
function system.setconsoleoutputcp(cp)
end

--- Get the width of a utf8 character for terminal display.
---@param char string
---@return integer? display_width in columns of the first character in the string (0 for an empty string)
---@return string? err
function system.utf8cwidth(char)
end

--- Get the width of a utf8 string for terminal display.
---@param str string
---@return integer? display_width of the string in columns (0 for an empty string)
---@return string? err
function system.utf8swidth(str)
end

--- Get system time. The time is returned as the seconds since the epoch (1 January 1970 00:00:00).
---@return number seconds
function system.gettime()
end

--- Get monotonic time. The time is returned as the seconds since system start.
---@return number seconds
function system.monotime()
end

--- Sleep without a busy loop. This function will sleep,
--- without doing a busy-loop and wasting CPU cycles.
---@param seconds number
---@param precision integer  minimum stepsize in milliseconds (Windows only, ignored elsewhere) (default: `16`)
---@return boolean?
---@return string? err
function system.sleep(seconds, precision)
end

--- Backs up terminal settings and restores them on application exit.
--- Calls `termbackup` to back up terminal settings and sets up a GC method
--- to automatically restore them on application exit (also works on Lua 5.1).
---@return boolean?
---@return string? err
function system.autotermrestore()
end

---@class luasystem.termbackup

--- Returns a backup of terminal settings for stdin/out/err.
--- Handles terminal/console flags, Windows codepage, and non-block flags on the streams.
--- Backs up terminal/console flags only if a stream is a tty.
---@return luasystem.termbackup
function system.termbackup()
end

--- Restores terminal settings from a backup.
---@param backup luasystem.termbackup
---@return boolean
function system.termrestore(backup)
end

--- Wraps a function to automatically restore terminal settings upon returning.
--- Calls `termbackup` before calling the function and `termrestore` after.
---@param f function
---@return function
function system.termwrap(f)
end
