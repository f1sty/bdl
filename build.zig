const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mod = b.createModule(.{ .optimize = optimize, .target = target, .root_source_file = b.path("src/main.zig") });
    mod.addImport("Scanner", b.createModule(.{ .optimize = optimize, .target = target, .root_source_file = b.path("src/Scanner.zig") }));
    mod.addImport("Parser", b.createModule(.{ .optimize = optimize, .target = target, .root_source_file = b.path("src/Parser.zig") }));

    const exe = b.addExecutable(.{ .name = "loof", .root_module = mod });

    b.installArtifact(exe);
}
