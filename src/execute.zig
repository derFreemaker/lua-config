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

child: std.process.Child,

pub fn init(allocator: std.mem.Allocator, argv: [][]const u8) Execute {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    return Execute{
        .child = child,
    };
}

pub fn deinit(self: *Execute) void {
    _ = self.child.kill() catch {};

    for (self.child.argv) |arg| {
        self.child.allocator.free(arg);
    }
    self.child.allocator.free(self.child.argv);
}

pub fn start(self: *Execute) ?[:0]const u8 {
    self.child.spawn() catch |err| switch (err) {
        //TODO: handle other cases better
        error.FileNotFound => return "file not found",
        else => return "unable to spawn process",
    };

    return null;
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

pub fn wait(self: *Execute, max_output_bytes: usize) !ExecuteResult {
    var stdout: std.ArrayListUnmanaged(u8) = .empty;
    defer stdout.deinit(self.child.allocator);
    var stderr: std.ArrayListUnmanaged(u8) = .empty;
    defer stderr.deinit(self.child.allocator);

    errdefer {
        _ = self.child.kill() catch {};
    }
    try self.child.collectOutput(self.child.allocator, &stdout, &stderr, max_output_bytes);

    const term = try self.child.wait();

    return ExecuteResult.init(
        self.child.allocator,
        term == .Exited and term.Exited == 0,
        switch (term) {
            .Exited => |e| e,
            .Signal => |s| s,
            .Stopped => |s| s,
            .Unknown => |u| u,
        },
        try stdout.toOwnedSlice(self.child.allocator),
        try stderr.toOwnedSlice(self.child.allocator),
    );
}
