# NOT FINISHED & NOT RECOMMENDED
Its a personal project there for its not good code or optimized.
This is not regulary tested / used on linux there are linux needed files included like lfs.so for linux.

# lua-config
Configuration loader in lua to load configurations for multiple PCs or platforms configuration, while maintaing one config repo for example windows, linux and maybe portable.
This is simply an lua which just brings some interaction to the filesystem as well as environment variable handling.

## Get Started
1. clone repo
2. execute `lua-config` or `lua-config.bat` in `bin` directory
3. create a file called `init.lua` in the parent directory of the repo (the parent directory is expected to be the config root)

## Usage
- `config.env` for environment variable managment
- `config.path` for some path things
- `config` global for configuration utils

All args are configured by the user the arg parser setup is just done for you. There for there are no args for lua-config.
Use `config.parse_args()` to parse the args after configuring the `config.args_parser`.

## Builtin
- For filesystem interactions [lua-filesystem](https://lunarmodules.github.io/luafilesystem) is comming with it and can be access with the `lfs` global.

## Third-Party
- [argparse](https://github.com/mpeterv/argparse)
- [lua-filesystem](https://lunarmodules.github.io/luafilesystem)
