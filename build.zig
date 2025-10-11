const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlua = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
        
        .lang = .lua54,
        .shared = false,
    }).module("zlua");

    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,

        .root_source_file = b.path("src/root.zig"),

        .imports = &.{
            .{ .name = "zlua", .module = zlua },
        },
    });

    const lib = b.addLibrary(.{
        .name = "lua_config",

        .linkage = .dynamic,
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
