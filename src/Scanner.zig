const Scanner = @This();
const std = @import("std");

reader: std.Io.Reader,
source: []const u8,
line: u64 = 1,
line_position: u64 = 1,
allocator: std.mem.Allocator,
tokens: std.ArrayList(Token) = .empty,

const Token = union(enum) {
    integer: []const u8,
    double: []const u8,
    string: []const u8,
    nil: []const u8,
    identifier: []const u8,
    @"var": []const u8,
    @"return": []const u8,
    @"and": []const u8,
    class: []const u8,
    @"else": []const u8,
    false: []const u8,
    true: []const u8,
    fun: []const u8,
    @"for": []const u8,
    @"if": []const u8,
    @"or": []const u8,
    print: []const u8,
    super: []const u8,
    this: []const u8,
    @"while": []const u8,
    right_paren: []const u8,
    left_paren: []const u8,
    right_brace: []const u8,
    left_brace: []const u8,
    comma: []const u8,
    dot: []const u8,
    assign: []const u8,
    equal: []const u8,
    less: []const u8,
    less_equal: []const u8,
    greater: []const u8,
    greater_equal: []const u8,
    bang: []const u8,
    bang_equal: []const u8,
    eof: []const u8,
    plus: []const u8,
    minus: []const u8,
    star: []const u8,
    slash: []const u8,
    semicolon: []const u8,

    pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            inline else => |value, tag| {
                try writer.print("{s}: {s}", .{ @tagName(tag), value });
            },
        }
    }
};

pub fn init(allocator: std.mem.Allocator, source: []const u8) !@This() {
    return .{ .allocator = allocator, .reader = .fixed(source), .source = source };
}

pub fn deinit(self: *@This()) void {
    self.tokens.deinit(self.allocator);
}

pub fn scanTokens(self: *@This()) !std.ArrayList(Token) {
    while (self.reader.takeByte()) |byte| {
        try self.scanChar(byte);
    } else |err| switch (err) {
        error.EndOfStream => {
            try self.tokens.append(self.allocator, .{ .eof = "" });
            return self.tokens;
        },
        else => |e| return e,
    }

    return self.tokens;
}

fn reportError(self: *@This(), caller: []const u8, message: []const u8) void {
    std.log.err("[{d}:{d}] Error {s}: {s}\n", .{ self.line, self.line_position + 1, caller, message });
}

fn scanChar(self: *@This(), char: u8) error{ OutOfMemory, EndOfStream, ReadFailed, StreamTooLong, UnknownToken }!void {
    const start = self.reader.seek - 1;
    switch (char) {
        ' ', '\t' => {},
        '\n' => {
            self.line += 1;
            self.line_position = 1;
        },
        ';' => try self.tokens.append(self.allocator, .{ .semicolon = self.source[self.reader.seek - 1 .. self.reader.seek] }),
        '=' => {
            switch (try self.reader.takeByte()) {
                '=' => try self.tokens.append(self.allocator, .{ .equal = self.source[start..self.reader.seek] }),
                else => |c| {
                    try self.tokens.append(self.allocator, .{ .assign = self.source[start .. self.reader.seek - 1] });
                    try self.scanChar(c);
                },
            }
        },
        '<' => {
            switch (try self.reader.takeByte()) {
                '=' => try self.tokens.append(self.allocator, .{ .less_equal = self.source[start..self.reader.seek] }),
                else => |c| {
                    try self.tokens.append(self.allocator, .{ .less = self.source[start .. self.reader.seek - 1] });
                    try self.scanChar(c);
                },
            }
        },
        '>' => {
            switch (try self.reader.takeByte()) {
                '=' => try self.tokens.append(self.allocator, .{ .greater_equal = self.source[start..self.reader.seek] }),
                else => |c| {
                    try self.tokens.append(self.allocator, .{ .greater = self.source[start .. self.reader.seek - 1] });
                    try self.scanChar(c);
                },
            }
        },
        '!' => {
            switch (try self.reader.takeByte()) {
                '=' => try self.tokens.append(self.allocator, .{ .bang_equal = self.source[start..self.reader.seek] }),
                else => |c| {
                    try self.tokens.append(self.allocator, .{ .bang = self.source[start .. self.reader.seek - 1] });
                    try self.scanChar(c);
                },
            }
        },
        '+' => try self.tokens.append(self.allocator, .{ .plus = self.source[start..self.reader.seek] }),
        '-' => try self.tokens.append(self.allocator, .{ .minus = self.source[start..self.reader.seek] }),
        '/' => try self.tokens.append(self.allocator, .{ .slash = self.source[start..self.reader.seek] }),
        '*' => try self.tokens.append(self.allocator, .{ .star = self.source[start..self.reader.seek] }),
        ',' => try self.tokens.append(self.allocator, .{ .comma = self.source[start..self.reader.seek] }),
        '.' => try self.tokens.append(self.allocator, .{ .dot = self.source[start..self.reader.seek] }),
        ')' => try self.tokens.append(self.allocator, .{ .right_paren = self.source[start..self.reader.seek] }),
        '(' => try self.tokens.append(self.allocator, .{ .left_paren = self.source[start..self.reader.seek] }),
        '}' => try self.tokens.append(self.allocator, .{ .right_brace = self.source[start..self.reader.seek] }),
        '{' => try self.tokens.append(self.allocator, .{ .left_brace = self.source[start..self.reader.seek] }),
        '0'...'9' => try self.scanNumber(),
        '"' => try self.scanString(),
        'a'...'z', 'A'...'Z', '_' => try self.scanIdentifier(),
        else => {
            self.reportError("scanner", "Unknown Token");
            return error.UnknownToken;
        },
    }
    self.line_position += 1;
}

// TODO: make number scanning more sophisticated (e.g. handle 01 number)
fn scanNumber(self: *@This()) !void {
    const start = self.reader.seek - 1;

    while (self.reader.takeByte()) |byte| {
        if (!std.ascii.isDigit(byte)) {
            try self.tokens.append(self.allocator, .{ .integer = self.source[start .. self.reader.seek - 1] });
            try self.scanChar(byte);
            break;
        }
    } else |err| switch (err) {
        error.EndOfStream => try self.tokens.append(self.allocator, .{ .integer = self.source[start..self.reader.seek] }),
        else => |e| return e,
    }
}

// TODO: handle broken string literal
fn scanString(self: *@This()) !void {
    const string = try self.reader.takeDelimiter('"') orelse "";
    try self.tokens.append(self.allocator, .{ .string = string });
}

fn scanIdentifier(self: *@This()) !void {
    const start = self.reader.seek - 1;

    while (self.reader.takeByte()) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and !std.mem.eql(u8, &.{byte}, "_")) {
            try self.classifyAndAppend(self.source[start .. self.reader.seek - 1]);
            try self.scanChar(byte);
            break;
        }
    } else |err| switch (err) {
        error.EndOfStream => try self.classifyAndAppend(self.source[start..self.reader.seek]),
        else => |e| return e,
    }
}

fn classifyAndAppend(self: *@This(), buffer: []const u8) !void {
    var token: Token = undefined;

    if (std.mem.eql(u8, buffer, "var")) {
        token = .{ .@"var" = buffer };
    } else if (std.mem.eql(u8, buffer, "and")) {
        token = .{ .@"and" = buffer };
    } else if (std.mem.eql(u8, buffer, "class")) {
        token = .{ .class = buffer };
    } else if (std.mem.eql(u8, buffer, "else")) {
        token = .{ .@"else" = buffer };
    } else if (std.mem.eql(u8, buffer, "fun")) {
        token = .{ .fun = buffer };
    } else if (std.mem.eql(u8, buffer, "for")) {
        token = .{ .@"for" = buffer };
    } else if (std.mem.eql(u8, buffer, "if")) {
        token = .{ .@"if" = buffer };
    } else if (std.mem.eql(u8, buffer, "nil")) {
        token = .{ .nil = buffer };
    } else if (std.mem.eql(u8, buffer, "or")) {
        token = .{ .@"or" = buffer };
    } else if (std.mem.eql(u8, buffer, "print")) {
        token = .{ .print = buffer };
    } else if (std.mem.eql(u8, buffer, "return")) {
        token = .{ .@"return" = buffer };
    } else if (std.mem.eql(u8, buffer, "super")) {
        token = .{ .super = buffer };
    } else if (std.mem.eql(u8, buffer, "this")) {
        token = .{ .this = buffer };
    } else if (std.mem.eql(u8, buffer, "while")) {
        token = .{ .@"while" = buffer };
    } else if (std.mem.eql(u8, buffer, "true")) {
        token = .{ .true = buffer };
    } else if (std.mem.eql(u8, buffer, "false")) {
        token = .{ .false = buffer };
    } else {
        token = .{ .identifier = buffer };
    }

    try self.tokens.append(self.allocator, token);
}
