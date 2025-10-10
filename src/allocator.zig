const std = @import("std");
const builtin = @import("builtin");

const Lua = @import("common/lua.zig");

const Allocator = @This();

pub const __luaMeta = Lua.StructMeta{
    .name = "lua-config.allocator",
    .meta_fields = &.{
        Lua.StructMeta.method(&Allocator.deinit, "__gc"),
    },
};

var gpa: std.heap.GeneralPurposeAllocator(if (builtin.mode == .Debug) .{
    .retain_metadata = true,
    .never_unmap = true,
} else .{}) = .init;

arena: if (builtin.mode == .Debug) void else std.heap.ArenaAllocator,

pub fn init() Allocator {
    return Allocator{
        .arena = if (builtin.mode == .Debug) {} else std.heap.ArenaAllocator.init(gpa.allocator()),
    };
}

pub fn deinit(self: *Allocator) void {
    if (comptime builtin.mode != .Debug) {
        self.arena.deinit();
    }

    _ = gpa.deinit();
}

pub fn allocator(self: *Allocator) std.mem.Allocator {
    if (comptime builtin.mode == .Debug) {
        return gpa.allocator();
    }

    return self.arena.allocator();
}
