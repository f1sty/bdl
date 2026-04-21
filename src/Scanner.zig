const Scanner = @This();
const std = @import("std");

reader: std.Io.Reader,
allocator: std.mem.Allocator,
tokens: std.ArrayList(Token),

const Token = union(enum) {
    boolean: bool,
    integer: []const u8,
    double: f64,
    string: []const u8,
    nil: u1,
    identifier: []const u8,
    keyword: []const u8,
    right_paren: u8,
    left_paren: u8,
    assign: u8,
    equal: u8,
    less: u8,
    more: u8,
    eol: u8,
    plus: u8,
    minus: u8,
    multiply: u8,
    divide: u8,
    expr_end: u8,
};

pub fn init(allocator: std.mem.Allocator, source: []const u8) !@This() {
    return .{ .allocator = allocator, .reader = .fixed(source), .tokens = try .initCapacity(allocator, 10) };
}

pub fn scanTokens(self: *@This()) !std.ArrayList(Token) {
    while (self.reader.takeByte()) |byte| {
        try self.scanChar(byte);
    } else |err| switch (err) {
        error.EndOfStream => return self.tokens,
        else => |e| return e,
    }

    return self.tokens;
}

fn scanChar(self: *@This(), char: u8) error{ OutOfMemory, ReadFailed, StreamTooLong }!void {
    switch (char) {
        ' ', '\t' => {},
        '\n' => try self.tokens.append(self.allocator, .{ .eol = '\n' }),
        ';' => try self.tokens.append(self.allocator, .{ .expr_end = ';' }),
        '=' => try self.tokens.append(self.allocator, .{ .assign = '=' }),
        '<' => try self.tokens.append(self.allocator, .{ .less = '<' }),
        '>' => try self.tokens.append(self.allocator, .{ .more = '>' }),
        '+' => try self.tokens.append(self.allocator, .{ .plus = '+' }),
        '-' => try self.tokens.append(self.allocator, .{ .minus = '-' }),
        '/' => try self.tokens.append(self.allocator, .{ .divide = '/' }),
        '*' => try self.tokens.append(self.allocator, .{ .multiply = '*' }),
        ')' => try self.tokens.append(self.allocator, .{ .right_paren = ')' }),
        '(' => try self.tokens.append(self.allocator, .{ .left_paren = '(' }),
        '1'...'9' => |ch| try self.scanNumber(ch),
        '"' => try self.scanString(),
        'a'...'z', 'A'...'Z', '_' => |ch| try self.scanIdentifier(ch),
        else => unreachable,
    }
}

fn scanNumber(self: *@This(), start_char: u8) !void {
    var number_buffer: std.ArrayList(u8) = try .initCapacity(self.allocator, 1);
    defer number_buffer.deinit(self.allocator);

    try number_buffer.append(self.allocator, start_char);

    while (self.reader.takeByte()) |byte| {
        if (!std.ascii.isDigit(byte)) {
            try self.tokens.append(self.allocator, .{ .integer = try number_buffer.toOwnedSlice(self.allocator) });
            try self.scanChar(byte);
            break;
        }
        try number_buffer.append(self.allocator, byte);
    } else |err| switch (err) {
        error.EndOfStream => try self.tokens.append(self.allocator, .{ .integer = try number_buffer.toOwnedSlice(self.allocator) }),
        else => |e| return e,
    }
}

// TODO: handle broken string literal
fn scanString(self: *@This()) !void {
    const string = try self.reader.takeDelimiter('"') orelse "";
    try self.tokens.append(self.allocator, .{ .string = string });
}

fn scanIdentifier(self: *@This(), start_char: u8) !void {
    var identifier: std.ArrayList(u8) = try .initCapacity(self.allocator, 1);
    defer identifier.deinit(self.allocator);

    try identifier.append(self.allocator, start_char);

    while (self.reader.takeByte()) |byte| {
        if (!std.ascii.isAlphanumeric(byte)) {
            try self.tokens.append(self.allocator, .{ .identifier = try identifier.toOwnedSlice(self.allocator) });
            try self.scanChar(byte);
            break;
        }
        try identifier.append(self.allocator, byte);
    } else |err| switch (err) {
        error.EndOfStream => try self.tokens.append(self.allocator, .{ .identifier = try identifier.toOwnedSlice(self.allocator) }),
        else => |e| return e,
    }
}
