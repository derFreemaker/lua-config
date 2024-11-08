# NOT FINISHED & NOT RECOMMENDED
Its a personal project there for its not good code or optimized.
This is not regulary tested / used on linux there are linux needed files included like lfs.so for linux.

# lua-config
Configuration loader in lua to load configurations for multiple PCs or platforms configuration, while maintaing one config repo for example windows, linux and maybe portable.
This simply a extension which just brings some interaction to the filesystem as well as environment variable handling.

## Get Started
1. clone repo
2. use `lua-config/.bat` in bin directory
3. create a file called `init.lua` in the parent directory of the repo

## Usage
- `env` global for environment variable managment
- `config` global for configuration utils

## Builtin
- For filesystem interactions [lua-filesystem](https://lunarmodules.github.io/luafilesystem) is comming with it and can be required with `require("lfs")`.

## Third-Party
- [argparse](https://github.com/mpeterv/argparse)
- [lua-filesystem](https://lunarmodules.github.io/luafilesystem)
