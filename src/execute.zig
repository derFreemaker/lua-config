const std = @import("std");

const Lua = @import("common/lua.zig");

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config.execute",
    .fields = &.{
        Lua.StructMeta.method(&wait, "wait"),
    },
    .meta_fields = &.{
        Lua.StructMeta.method(&deinit, "__gc"),
    },
};

const Execute = @This();

allocator: std.mem.Allocator,
io: std.Io,

child: std.process.Child,

pub fn init(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) std.process.SpawnError!Execute {
    const child = try std.process.spawn(io, .{
        .argv = argv,

        .stdout = .pipe,
        .stderr = .pipe,
    });
    errdefer child.kill(io);

    return Execute{
        .allocator = allocator,
        .io = io,

        .child = child,
    };
}

pub fn deinit(self: *Execute) void {
    self.child.kill(self.io);
}

pub const ExecuteResult = struct {
    pub const __luaMeta = Lua.StructMeta{
        .name = "lua-config.execute.result",
        .fields = &.{
            Lua.StructMeta.property("success"),
            Lua.StructMeta.property("exitcode"),
            Lua.StructMeta.property("stdout"),
            Lua.StructMeta.property("stderr"),
        },
        .meta_fields = &.{Lua.StructMeta.method(&ExecuteResult.deinit, "__gc")},
    };

    success: bool,
    exitcode: u32,

    allocator: std.mem.Allocator,
    stdout: []const u8,
    stderr: []const u8,

    pub fn init(allocator: std.mem.Allocator, success: bool, exitcode: u32, stdout: []const u8, stderr: []const u8) ExecuteResult {
        return ExecuteResult{
            .success = success,
            .exitcode = exitcode,

            .allocator = allocator,

            .stdout = stdout,
            .stderr = stderr,
        };
    }

    pub fn deinit(self: *ExecuteResult) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }
};

pub fn wait(self: *Execute, max_output_bytes: usize, state: Lua.ThisState) !ExecuteResult {
    var stdout_buf = try self.allocator.alloc(u8, max_output_bytes);
    defer self.allocator.free(stdout_buf);
    var stderr_buf = try self.allocator.alloc(u8, max_output_bytes);
    defer self.allocator.free(stderr_buf);

    var stdout_reader_buf: [128]u8 = undefined;
    var stdout_reader = self.child.stdout.?.reader(self.io, &stdout_reader_buf);
    const stdout = &stdout_reader.interface;
    const stdout_str = stdout_buf[0 .. stdout.readSliceShort(stdout_buf) catch {
        state.lua.raiseErrorStr("unable to read stdout", .{});
    }];

    var stderr_reader_buf: [128]u8 = undefined;
    var stderr_reader = self.child.stderr.?.reader(self.io, &stderr_reader_buf);
    const stderr = &stderr_reader.interface;
    const stderr_str = stderr_buf[0 .. stderr.readSliceShort(stderr_buf) catch {
        state.lua.raiseErrorStr("unable to read stderr", .{});
    }];

    const term = try self.child.wait(self.io);

    const stdout_finial = try self.allocator.dupe(u8, stdout_str);
    errdefer self.allocator.free(stdout_finial);
    const stderr_finial = try self.allocator.dupe(u8, stderr_str);
    errdefer self.allocator.free(stderr_finial);

    return ExecuteResult.init(
        self.allocator,
        term == .exited and term.exited == 0,
        switch (term) {
            .exited => |e| e,
            .signal => |s| @intFromEnum(s),
            .stopped => |s| @intFromEnum(s),
            .unknown => |u| u,
        },
        stdout_finial,
        stderr_finial,
    );
}
