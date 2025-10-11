# NOT RECOMMENDED

Its a personal project there for its not good code or optimized.
Used for personal interest.

# lua-config

Configuration loader in lua to load configurations for multiple PCs or platforms configuration,
while maintaing one config repo for example windows, linux and windows portable.

## Get Started

1. clone repo
2. build lua-config lib with `zig build --release=safe`
3. create a file called `init.lua` in the parent directory of the repo (the parent directory is expected to be the config root)
4. execute `lua-config` or `lua-config.ps1` in `bin` directory

## Usage

There for there are no args for lua-config.
All args are configured by the user the arg parser is just setup for you.
Use `config.parse_args()` to parse the args after configuring with `config.args_parser`.

### Note

Also has a complete set of meta files.
It is recommended to require `luafilesystem` with `require("lua-config.third-party.lfs")`

## Dependencies

- [zig](https://ziglang.org/)
- [lua-filesystem](https://lunarmodules.github.io/luafilesystem)
- [luasystem](https://lunarmodules.github.io/luasystem)
- [busted](https://lunarmodules.github.io/busted) (only for testing)

## Third-Party

- [argparse](https://github.com/mpeterv/argparse)
