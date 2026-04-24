const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mod = b.createModule(.{ .optimize = optimize, .target = target, .root_source_file = b.path("src/main.zig") });
    const exe = b.addExecutable(.{ .name = "bdl", .root_module = mod });

    b.installArtifact(exe);
}
