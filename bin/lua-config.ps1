$LuaConfigDir = Split-Path -Parent $PSScriptRoot

lua "$LuaConfigDir/src/main.lua" "$LuaConfigDir" @args
