const std = @import("std");
const builtin = @import("builtin");

const Lua = @import("common/lua.zig");

const Environment = @This();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config.env",
    .fields = &.{
        Lua.StructMeta.getter(&getOS, "os"),
        Lua.StructMeta.getter(&checkElevated, "is_root"),
        Lua.StructMeta.getter(&getHostname, "hostname"),
    },
};

allocator: std.mem.Allocator,
env_map: *std.process.Environ.Map,

pub fn init(allocator: std.mem.Allocator, env_map: *std.process.Environ.Map) Environment {
    return Environment{
        .allocator = allocator,
        .env_map = env_map,
    };
}

fn getOS() [:0]const u8 {
    return @tagName(builtin.os.tag);
}

extern "shell32" fn IsUserAnAdmin() callconv(.winapi) std.os.windows.BOOL;
fn checkElevated() bool {
    return switch (comptime builtin.os.tag) {
        .windows => IsUserAnAdmin() != .FALSE,
        .linux, .macos => std.os.linux.getuid() == 0,
        else => false,
    };
}

fn getHostname(state: Lua.ThisState, self: *Environment) Lua.ReturnStackValues {
    if (comptime builtin.os.tag == .windows) {
        const name = self.env_map.get("COMPUTERNAME") orelse {
            state.lua.raiseErrorStr("hostname (aka 'COMPUTERNAME') not found in environment varaibles", .{});
        };

        state.push(name);
        return .extra;
    } else {
        var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
        const name = std.posix.gethostname(&buf) catch {
            state.lua.raiseErrorStr("unable to get hostname", .{});
        };

        state.push(name);
        return .extra;
    }
}
