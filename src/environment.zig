const std = @import("std");
const builtin = @import("builtin");

const Lua = @import("common/lua.zig");

const allocator = @import("allocator.zig").gpa.allocator();

const Reg = if (builtin.os.tag != .windows) void{} else @import("registry.zig");

const Environment = @This();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config.env",
    .fields = &.{
        Lua.StructMeta.property("is_windows"),

        Lua.StructMeta.getter(&getOS, "os"),
        Lua.StructMeta.getter(&checkElevated, "is_root"),
        Lua.StructMeta.getter(&getHostname, "hostname"),

        Lua.StructMeta.method(&get, "get"),
        Lua.StructMeta.method(&set, "set"),
    },
};

is_windows: bool,

pub fn init() Environment {
    return Environment{
        .is_windows = builtin.os.tag == .windows,
    };
}

fn getOS() [:0]const u8 {
    return @tagName(builtin.os.tag);
}

extern "shell32" fn IsUserAnAdmin() callconv(.x86_stdcall) std.os.windows.BOOL;
fn checkElevated() bool {
    if (comptime builtin.os.tag == .windows) {
        return IsUserAnAdmin() != 0;
    }

    return std.posix.getuid() == 0;
}

fn getHostname(state: Lua.ThisState) Lua.ReturnStackValues {
    if (comptime builtin.os.tag == .windows) {
        return get(state, "COMPUTERNAME");
    }

    var buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const name = std.posix.gethostname(&buf) catch {
        state.lua.raiseErrorStr("unable to get hostname", .{});
    };

    state.push(name);
    return .extra;
}

pub fn get(state: Lua.ThisState, key: [:0]const u8) Lua.ReturnStackValues {
    const value = std.process.getEnvVarOwned(allocator, key) catch {
        state.push("");
        return .extra;
    };
    defer allocator.free(value);

    state.push(value);
    return .extra;
}

extern "kernel32" fn SetEnvironmentVariableW(
    lpName: [*:0]const u16,
    lpValue: ?[*]const u16,
) callconv(.winapi) std.os.windows.Win32Error;

extern fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: i32) callconv(.c) i32;
extern fn unsetenv(name: [*:0]const u8) callconv(.c) i32;

pub fn set(name: [:0]const u8, value: ?[:0]const u8) bool {
    if (comptime builtin.os.tag == .windows) {
        const name_w = std.unicode.utf8ToUtf16LeAlloc(allocator, name) catch {
            return false;
        };
        defer allocator.free(name_w);

        if (value == null) {
            const result = SetEnvironmentVariableW(name_w.ptr, null);
            if (result != std.os.windows.TRUE) {
                return false;
            }

            return true;
        }

        const value_w = std.unicode.utf8ToUtf16LeAlloc(allocator, value.?) catch {
            return false;
        };
        defer allocator.free(value_w);

        const result = SetEnvironmentVariableW(name_w.ptr, value_w.ptr);
        if (result != std.os.windows.TRUE) {
            return false;
        }

        return true;
    }

    if (value == null) {
        const rc = unsetenv(name);
        if (rc != 0) {
            return false;
        }

        return true;
    }

    const overwrite: i32 = 1;
    const rc = setenv(name, value.?.ptr, overwrite);
    if (rc != 0) {
        return false;
    }

    return true;
}
