const std = @import("std");
const zlua = @import("zlua");

const Lua = @import("common/lua.zig");

const allocator = @import("allocator.zig").gpa.allocator();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config.fs",
    .fields = &.{
        Lua.StructMeta.method(&ch_dir, "chdir"),
        Lua.StructMeta.method(&current_dir, "currentdir"),
        Lua.StructMeta.method(&exists, "exists"),
        Lua.StructMeta.method(&children, "dir"),
        Lua.StructMeta.method(&mkdir, "mkdir"),
        Lua.StructMeta.method(&rmdir, "rmdir"),
        Lua.StructMeta.method(&create_symlink, "create_symlink"),
    },
};

const Fs = @This();

pub fn ch_dir(path: [:0]const u8) bool {
    const real_path = std.fs.cwd().realpathAlloc(allocator, path) catch {
        return false;
    };
    defer allocator.free(real_path);

    var new_cwd = std.fs.cwd().openDir(real_path, .{}) catch {
        return false;
    };
    defer new_cwd.close();

    new_cwd.setAsCwd() catch {
        return false;
    };
    return true;
}

pub fn current_dir(state: Lua.ThisState) Lua.ReturnStackValues {
    const path = std.fs.cwd().realpathAlloc(allocator, ".") catch {
        state.push(null);
        return .extra;
    };
    defer allocator.free(path);

    state.push(path);
    return .extra;
}

pub const DirIterator = struct {
    pub const __luaMeta = Lua.StructMeta{
        .name = "lua-config.fs.dir",
        .fields = &.{
            Lua.StructMeta.method(&DirIterator.next, "next"),
            Lua.StructMeta.method(&DirIterator.close, "close"),
        },
        .meta_fields = &.{
            Lua.StructMeta.method(&DirIterator.close, "__gc"),
        },
    };

    dir: std.fs.Dir,
    iterator: std.fs.Dir.Iterator,

    pub fn init(dir: std.fs.Dir) DirIterator {
        return DirIterator{
            .dir = dir,
            .iterator = dir.iterate(),
        };
    }

    pub fn close(self: *DirIterator) void {
        self.dir.close();
    }

    pub fn next(self: *DirIterator) ?[]const u8 {
        const entry = self.iterator.next() catch {
            return null;
        };
        if (entry == null) {
            return null;
        }

        return entry.?.name;
    }
};

pub fn exists(path: [:0]const u8) bool {
    const absolute_path = std.fs.cwd().realpathAlloc(allocator, path) catch {
        return false;
    };
    defer allocator.free(absolute_path);

    std.fs.accessAbsolute(absolute_path, .{}) catch |err| switch (err) {
        error.FileNotFound,
        error.NameTooLong,
        error.BadPathName,
        error.SymLinkLoop,
        error.InvalidUtf8,
        error.InvalidWtf8,
        error.Unexpected,
        => {
            return false;
        },

        else => {
            return true;
        },
    };

    return true;
}

pub fn children(state: Lua.ThisState, path: [:0]const u8) Lua.ReturnStackValues {
    const real_path = std.fs.cwd().realpathAlloc(allocator, path) catch {
        state.push(null);
        return .extra;
    };
    defer allocator.free(real_path);

    const dir = std.fs.openDirAbsolute(real_path, .{
        .iterate = true,
        .access_sub_paths = false,
    }) catch {
        state.push(null);
        return .extra;
    };

    state.push(DirIterator.init(dir));
    state.lua.pushValue(-1);
    state.lua.pushClosure(Lua.wrap(struct {
        pub fn func(s: Lua.ThisState) ?[]const u8 {
            const self = s.check(*DirIterator, zlua.Lua.upvalueIndex(1)).value;
            return self.next();
        }
    }.func), 1);
    state.lua.insert(state.lua.absIndex(-2));
    return .extra;
}

pub fn mkdir(path: [:0]const u8) bool {
    const real_path = blk: {
        if (std.fs.path.isAbsoluteZ(path)) {
            break :blk path;
        }

        const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch {
            return false;
        };
        defer allocator.free(cwd);

        break :blk std.fs.path.join(allocator, &.{ cwd, path }) catch {
            return false;
        };
    };
    defer if (!std.fs.path.isAbsoluteWindowsZ(path)) allocator.free(real_path);

    std.fs.makeDirAbsolute(real_path) catch {
        return false;
    };
    return true;
}

pub fn rmdir(path: [:0]const u8) bool {
    const real_path = std.fs.cwd().realpathAlloc(allocator, path) catch {
        return false;
    };
    defer allocator.free(real_path);

    std.fs.deleteDirAbsolute(real_path) catch {
        return false;
    };
    return true;
}

pub fn create_symlink(path: [:0]const u8, target: [:0]const u8, is_directory: bool) bool {
    const real_path = blk: {
        if (std.fs.path.isAbsoluteZ(path)) {
            break :blk path;
        }

        const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch {
            return false;
        };
        defer allocator.free(cwd);

        break :blk std.fs.path.join(allocator, &.{ cwd, path }) catch {
            return false;
        };
    };
    defer if (!std.fs.path.isAbsoluteWindowsZ(path)) allocator.free(real_path);

    const real_target = std.fs.cwd().realpathAlloc(allocator, target) catch {
        return false;
    };
    defer allocator.free(real_target);

    std.fs.symLinkAbsolute(real_target, real_path, .{ .is_directory = is_directory }) catch {
        return false;
    };
    return true;
}
