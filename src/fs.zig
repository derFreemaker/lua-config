const std = @import("std");
const builtin = @import("builtin");
const zlua = @import("zlua");

const Lua = @import("common/lua.zig");

const Fs = @This();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config.fs",
    .fields = &.{
        Lua.StructMeta.method(&attributes, "attributes"),
        Lua.StructMeta.method(&link_attributes, "link_attributes"),
        Lua.StructMeta.method(&ch_dir, "chdir"),
        Lua.StructMeta.method(&current_dir, "currentdir"),
        Lua.StructMeta.method(&exists, "exists"),
        Lua.StructMeta.method(&children, "dir"),
        Lua.StructMeta.method(&mkdir, "mkdir"),
        Lua.StructMeta.method(&rmdir, "rmdir"),
        Lua.StructMeta.method(&create_symlink, "create_symlink"),
    },
};

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Fs {
    return Fs{
        .allocator = allocator,
    };
}

pub fn ch_dir(self: *Fs, path: [:0]const u8) bool {
    const real_path = std.fs.cwd().realpathAlloc(self.allocator, path) catch {
        return false;
    };
    defer self.allocator.free(real_path);

    var new_cwd = std.fs.cwd().openDir(real_path, .{}) catch {
        return false;
    };
    defer new_cwd.close();

    new_cwd.setAsCwd() catch {
        return false;
    };
    return true;
}

pub fn current_dir(self: *Fs, state: Lua.ThisState) Lua.ReturnStackValues {
    const path = std.fs.cwd().realpathAlloc(self.allocator, ".") catch {
        state.push(null);
        return .extra;
    };
    defer self.allocator.free(path);

    state.push(path);
    return .extra;
}

pub fn attributes(self: *Fs, path: [:0]const u8, state: Lua.ThisState) Lua.ReturnStackValues {
    const real_path = std.fs.cwd().realpathAlloc(self.allocator, path) catch {
        return .none;
    };
    defer self.allocator.free(real_path);

    const file = std.fs.openFileAbsolute(real_path, .{}) catch {
        return .none;
    };
    const stat = file.stat() catch {
        return .none;
    };

    state.lua.createTable(0, 7);

    state.push(stat.inode);
    state.lua.setField(-2, "inode");

    state.push(stat.size);
    state.lua.setField(-2, "size");

    state.push(stat.mode);
    state.lua.setField(-2, "mode");

    state.push(@tagName(stat.kind));
    state.lua.setField(-2, "kind");

    state.push(@divTrunc(stat.atime, std.time.ns_per_ms));
    state.lua.setField(-2, "access_time");

    state.push(@divTrunc(stat.mtime, std.time.ns_per_ms));
    state.lua.setField(-2, "modified_time");

    state.push(@divTrunc(stat.ctime, std.time.ns_per_ms));
    state.lua.setField(-2, "created_time");

    return .extra;
}

pub fn link_attributes(self: *Fs, path: [:0]const u8, state: Lua.ThisState) Lua.ReturnStackValues {
    const raw_path = blk: {
        if (std.fs.path.isAbsoluteZ(path)) {
            break :blk path;
        }

        const cwd = std.fs.cwd().realpathAlloc(self.allocator, ".") catch {
            return .none;
        };
        defer self.allocator.free(cwd);

        break :blk std.fs.path.join(self.allocator, &.{ cwd, path }) catch {
            return .none;
        };
    };
    defer if (!std.fs.path.isAbsoluteZ(path)) self.allocator.free(raw_path);

    const dir_path = std.fs.path.dirname(raw_path) orelse ".";
    var dir = std.fs.openDirAbsolute(dir_path, .{}) catch {
        return .none;
    };
    defer dir.close();

    const file_name = std.fs.path.basename(raw_path);
    const file = dir.openFile(file_name, .{}) catch {
        return .none;
    };
    const stat = file.stat() catch {
        return .none;
    };

    state.lua.createTable(0, 8);

    state.push(stat.inode);
    state.lua.setField(-2, "inode");

    state.push(stat.size);
    state.lua.setField(-2, "size");

    state.push(stat.mode);
    state.lua.setField(-2, "mode");

    state.push(@tagName(stat.kind));
    state.lua.setField(-2, "kind");

    state.push(@divTrunc(stat.atime, std.time.ns_per_ms));
    state.lua.setField(-2, "access_time");

    state.push(@divTrunc(stat.mtime, std.time.ns_per_ms));
    state.lua.setField(-2, "modified_time");

    state.push(@divTrunc(stat.ctime, std.time.ns_per_ms));
    state.lua.setField(-2, "created_time");

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const target = dir.readLink(file_name, &buf) catch {
        return .none;
    };

    state.push(target);
    state.lua.setField(-2, "target");

    return .extra;
}

pub fn exists(self: *Fs, path: [:0]const u8) bool {
    const real_path = std.fs.cwd().realpathAlloc(self.allocator, path) catch {
        return false;
    };
    defer self.allocator.free(real_path);

    std.fs.accessAbsolute(real_path, .{}) catch |err| switch (err) {
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

pub fn children(self: *Fs, state: Lua.ThisState, path: [:0]const u8) Lua.ReturnStackValues {
    const real_path = std.fs.cwd().realpathAlloc(self.allocator, path) catch {
        state.push(null);
        return .extra;
    };
    defer self.allocator.free(real_path);

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
            const iter = s.check(*DirIterator, zlua.Lua.upvalueIndex(1)).value;
            return iter.next();
        }
    }.func), 1);
    state.lua.insert(state.lua.absIndex(-2));
    return .extra;
}

pub fn mkdir(self: *Fs, path: [:0]const u8) bool {
    const real_path = blk: {
        if (std.fs.path.isAbsoluteZ(path)) {
            break :blk path;
        }

        const cwd = std.fs.cwd().realpathAlloc(self.allocator, ".") catch {
            return false;
        };
        defer self.allocator.free(cwd);

        break :blk std.fs.path.join(self.allocator, &.{ cwd, path }) catch {
            return false;
        };
    };
    defer if (!std.fs.path.isAbsoluteWindowsZ(path)) self.allocator.free(real_path);

    std.fs.makeDirAbsolute(real_path) catch {
        return false;
    };
    return true;
}

pub fn rmdir(self: *Fs, path: [:0]const u8) bool {
    const real_path = std.fs.cwd().realpathAlloc(self.allocator, path) catch {
        return false;
    };
    defer self.allocator.free(real_path);

    std.fs.deleteDirAbsolute(real_path) catch {
        return false;
    };
    return true;
}

pub fn create_symlink(self: *Fs, path: [:0]const u8, target: [:0]const u8, is_directory: bool) bool {
    const real_path = blk: {
        if (std.fs.path.isAbsoluteZ(path)) {
            break :blk path;
        }

        const cwd = std.fs.cwd().realpathAlloc(self.allocator, ".") catch {
            return false;
        };
        defer self.allocator.free(cwd);

        break :blk std.fs.path.join(self.allocator, &.{ cwd, path }) catch {
            return false;
        };
    };
    defer if (!std.fs.path.isAbsoluteZ(path)) self.allocator.free(real_path);

    const real_target = std.fs.cwd().realpathAlloc(self.allocator, target) catch {
        return false;
    };
    defer self.allocator.free(real_target);

    std.fs.symLinkAbsolute(real_target, real_path, .{ .is_directory = is_directory }) catch {
        return false;
    };
    return true;
}
