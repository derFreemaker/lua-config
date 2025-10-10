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

gpa: std.heap.GeneralPurposeAllocator(if (builtin.mode == .Debug) .{
    .retain_metadata = true,
    .never_unmap = true,
} else .{}),

pub fn init() Allocator {
    return Allocator{
        .gpa = .init,
    };
}

pub fn deinit(self: *Allocator) void {
    _ = self.gpa.deinit();
}

pub fn allocator(self: *Allocator) std.mem.Allocator {
    return self.gpa.allocator();
}
