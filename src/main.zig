const std = @import("std");
const Scanner = @import("Scanner");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.gpa);
    defer init.gpa.free(args);

    var w = std.Io.File.stdout().writer(init.io, &.{});
    if (args.len > 2) {
        try w.interface.print("Usage: {s} [script_name]\n", .{args[0]});
    } else if (args.len == 2) {
        try runFile(init.gpa, init.io, args[1]);
    } else {
        try runPrompt(init.gpa, init.io);
    }
    try w.flush();
}

fn runFile(allocator: std.mem.Allocator, io: std.Io, file_path: []const u8) !void {
    var real_path: [4096]u8 = undefined;
    const path_size = try std.Io.Dir.cwd().realPathFile(io, file_path, &real_path);
    const file = try std.Io.Dir.openFileAbsolute(io, real_path[0..path_size], .{ .mode = .read_only });

    var buffer: [10 * 1024]u8 = undefined;
    const size = try file.readPositionalAll(io, &buffer, 0);

    try run(allocator, io, buffer[0..size]);
}

fn runPrompt(allocator: std.mem.Allocator, io: std.Io) !void {
    var buffer: [4096]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &buffer);
    var writer = std.Io.File.stdout().writer(io, &.{});

    while (true) {
        _ = try writer.interface.write("> ");
        try writer.flush();

        const line = try reader.interface.takeDelimiter('\n') orelse "";

        try run(allocator, io, line);
    }
}

fn run(allocator: std.mem.Allocator, io: std.Io, source: []const u8) !void {
    var scanner = try Scanner.init(allocator, source);
    var writer = std.Io.File.stdout().writer(io, &.{});

    const tokens = try scanner.scanTokens();
    for (tokens.items) |token| {
        try writer.interface.print("{any}\n", .{token});
        try writer.flush();
    }
}
