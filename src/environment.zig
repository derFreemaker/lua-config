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

pub fn init(allocator: std.mem.Allocator) Environment {
    return Environment{
        .allocator = allocator,
    };
}

fn getOS() [:0]const u8 {
    return @tagName(builtin.os.tag);
}

extern "shell32" fn IsUserAnAdmin() callconv(.winapi) std.os.windows.BOOL;
fn checkElevated() bool {
    if (comptime builtin.os.tag == .windows) {
        return IsUserAnAdmin() != 0;
    }

    return std.posix.getuid() == 0;
}

fn getHostname(state: Lua.ThisState, self: *Environment) Lua.ReturnStackValues {
    if (comptime builtin.os.tag == .windows) {
        const value = std.process.getEnvVarOwned(self.allocator, "COMPUTERNAME") catch {
            state.push(null);
            return .extra;
        };
        defer self.allocator.free(value);

        state.push(value);
        return .extra;
    }

    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const name = std.posix.gethostname(&buf) catch {
        state.lua.raiseErrorStr("unable to get hostname", .{});
    };

    state.push(name);
    return .extra;
}
