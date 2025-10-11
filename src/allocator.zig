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

alloc: if (builtin.mode == .Debug) std.heap.GeneralPurposeAllocator(.{
    .retain_metadata = true,
    .never_unmap = true,
}) else std.heap.ArenaAllocator,

pub fn init() Allocator {
    return Allocator{
        .alloc = if (builtin.mode == .Debug) .init else std.heap.ArenaAllocator.init(std.heap.page_allocator),
    };
}

pub fn deinit(self: *Allocator) void {
    if (comptime builtin.mode == .Debug) {
        _ = self.alloc.deinit();
    } else {
        self.alloc.deinit();
    }
}

pub fn allocator(self: *Allocator) std.mem.Allocator {
    return self.alloc.allocator();
}
