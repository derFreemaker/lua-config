const std = @import("std");

// we initialize in here and free in root.zig
pub var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
