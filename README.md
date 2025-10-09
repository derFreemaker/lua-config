# NOT RECOMMENDED

Its a personal project there for its not good code or optimized.
Used for personal interest.

# lua-config

Configuration loader in lua to load configurations for multiple PCs or platforms configuration, while maintaing one config repo for example windows, linux and maybe portable.
This is simply an lua which just brings some interaction to the filesystem as well as environment variable handling.

## Get Started

1. clone repo
2. create a file called `init.lua` in the parent directory of the repo (the parent directory is expected to be the config root)
3. execute `lua-config` or `lua-config.bat` in `bin` directory

## Usage

There for there are no args for lua-config.
All args are configured by the user the arg parser is just setup for you.
Use `config.parse_args()` to parse the args after configuring with `config.args_parser`.

## Dependencies

- [lua-filesystem](https://lunarmodules.github.io/luafilesystem)
- [busted](https://lunarmodules.github.io/busted)

## Third-Party

- [argparse](https://github.com/mpeterv/argparse)
- [lua-filesystem](https://lunarmodules.github.io/luafilesystem)
