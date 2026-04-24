const Scanner = @This();
const std = @import("std");

r: std.Io.Reader,
src: []const u8,
line_number: u32 = 1,
line_position: u32 = 1,
allocator: std.mem.Allocator,
tokens: std.ArrayList(Token) = .empty,

const Token = union(enum) {
    identifier: []const u8,
    string: []const u8,
    i64: []const u8,
    f64: []const u8,
    hash: []const u8,
    at: []const u8,
    bang: []const u8,
    qmark: []const u8,
    colon: []const u8,
    arrow: []const u8,
    dollar: []const u8,
    percent: []const u8,
    comma: []const u8,
    @"if": []const u8,
    @"else": []const u8,
    @"while": []const u8,
    @"or": []const u8,
    xor: []const u8,
    @"and": []const u8,
    not: []const u8,
    @"for": []const u8,
    nil: []const u8,
    true: []const u8,
    false: []const u8,
    print: []const u8,
    left_sbracket: []const u8,
    right_sbracket: []const u8,
    left_bracket: []const u8,
    right_bracket: []const u8,
    left_brace: []const u8,
    right_brace: []const u8,
    equal: []const u8,
    equal_equal: []const u8,
    greater_equal: []const u8,
    less_equal: []const u8,
    greater: []const u8,
    less: []const u8,
    plus_equal: []const u8,
    minus_equal: []const u8,
    star_equal: []const u8,
    slash_equal: []const u8,
    plus: []const u8,
    minus: []const u8,
    star: []const u8,
    slash: []const u8,
    block: []const u8,
    eof: []const u8,

    pub fn format(self: Token, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            inline else => |value, tag| {
                try writer.print("{s}: {s}", .{ @tagName(tag), value });
            },
        }
    }
};

pub fn init(allocator: std.mem.Allocator, source: []const u8) !Scanner {
    return .{ .allocator = allocator, .r = .fixed(source), .src = source };
}

pub fn deinit(self: *Scanner) void {
    self.tokens.deinit(self.allocator);
}

pub fn scanTokens(self: *Scanner) !std.ArrayList(Token) {
    while (self.r.takeByte()) |byte| {
        try self.scanByte(byte);
    } else |err| switch (err) {
        error.EndOfStream => {
            try self.tokens.append(self.allocator, .{ .eof = "" });
            return self.tokens;
        },
        else => |e| {
            self.reportError("scanTokens", e);
            return e;
        },
    }
}

fn reportError(self: *Scanner, caller: []const u8, err: anyerror) void {
    std.log.err("[{d}:{d}] Error in {s}: {s}\n", .{ self.line_number, self.line_position + 1, caller, @errorName(err) });
}

fn addToken(self: *Scanner, token: Token) !void {
    try self.tokens.append(self.allocator, token);
}

fn scanByte(self: *Scanner, byte: u8) !void {
    sw: switch (byte) {
        ' ', '\t', '\r' => {},
        '\n' => {
            self.line_number += 1;
            self.line_position = 1;
        },
        '#' => try self.addToken(.{ .hash = self.src[self.r.seek - 1 .. self.r.seek] }),
        '@' => try self.addToken(.{ .at = self.src[self.r.seek - 1 .. self.r.seek] }),
        '!' => try self.addToken(.{ .bang = self.src[self.r.seek - 1 .. self.r.seek] }),
        '?' => try self.addToken(.{ .qmark = self.src[self.r.seek - 1 .. self.r.seek] }),
        ':' => try self.addToken(.{ .colon = self.src[self.r.seek - 1 .. self.r.seek] }),
        '$' => try self.addToken(.{ .dollar = self.src[self.r.seek - 1 .. self.r.seek] }),
        '%' => try self.addToken(.{ .percent = self.src[self.r.seek - 1 .. self.r.seek] }),
        ',' => try self.addToken(.{ .comma = self.src[self.r.seek - 1 .. self.r.seek] }),
        '[' => try self.addToken(.{ .left_sbracket = self.src[self.r.seek - 1 .. self.r.seek] }),
        ']' => try self.addToken(.{ .right_sbracket = self.src[self.r.seek - 1 .. self.r.seek] }),
        '{' => try self.addToken(.{ .left_brace = self.src[self.r.seek - 1 .. self.r.seek] }),
        '}' => try self.addToken(.{ .right_brace = self.src[self.r.seek - 1 .. self.r.seek] }),
        '(' => try self.addToken(.{ .left_bracket = self.src[self.r.seek - 1 .. self.r.seek] }),
        ')' => try self.addToken(.{ .right_bracket = self.src[self.r.seek - 1 .. self.r.seek] }),
        '|' => try self.addToken(.{ .block = self.src[self.r.seek - 1 .. self.r.seek] }),
        '"' => try self.scanStringLiteral(),
        '=' => {
            const start = self.r.seek - 1;
            switch (try self.r.takeByte()) {
                '=' => try self.addToken(.{ .equal_equal = self.src[start..self.r.seek] }),
                else => |next_byte| {
                    try self.addToken(.{ .equal = self.src[start .. self.r.seek - 1] });
                    continue :sw next_byte;
                },
            }
        },
        '>' => {
            const start = self.r.seek - 1;
            switch (try self.r.takeByte()) {
                '=' => try self.addToken(.{ .greater_equal = self.src[start..self.r.seek] }),
                else => |next_byte| {
                    try self.addToken(.{ .greater = self.src[start .. self.r.seek - 1] });
                    continue :sw next_byte;
                },
            }
        },
        '<' => {
            const start = self.r.seek - 1;
            switch (try self.r.takeByte()) {
                '=' => try self.addToken(.{ .less_equal = self.src[start..self.r.seek] }),
                else => |next_byte| {
                    try self.addToken(.{ .less = self.src[start .. self.r.seek - 1] });
                    continue :sw next_byte;
                },
            }
        },
        '+' => {
            const start = self.r.seek - 1;
            switch (try self.r.takeByte()) {
                '=' => try self.addToken(.{ .plus_equal = self.src[start..self.r.seek] }),
                else => |next_byte| {
                    try self.addToken(.{ .plus = self.src[start .. self.r.seek - 1] });
                    continue :sw next_byte;
                },
            }
        },
        '-' => {
            const start = self.r.seek - 1;
            switch (try self.r.takeByte()) {
                '=' => try self.addToken(.{ .minus_equal = self.src[start..self.r.seek] }),
                '>' => try self.addToken(.{ .arrow = self.src[start..self.r.seek] }),
                else => |next_byte| {
                    try self.addToken(.{ .minus = self.src[start .. self.r.seek - 1] });
                    continue :sw next_byte;
                },
            }
        },
        '*' => {
            const start = self.r.seek - 1;
            switch (try self.r.takeByte()) {
                '=' => try self.addToken(.{ .star_equal = self.src[start..self.r.seek] }),
                else => |next_byte| {
                    try self.addToken(.{ .star = self.src[start .. self.r.seek - 1] });
                    continue :sw next_byte;
                },
            }
        },
        '/' => {
            const start = self.r.seek - 1;
            switch (try self.r.takeByte()) {
                '=' => try self.addToken(.{ .slash_equal = self.src[start..self.r.seek] }),
                else => |next_byte| {
                    try self.addToken(.{ .slash = self.src[start .. self.r.seek - 1] });
                    continue :sw next_byte;
                },
            }
        },
        'a'...'z', 'A'...'Z', '_' => try self.scanLiteralOrKeyword(),
        '0'...'9' => try self.scanNumber(),
        else => {
            self.reportError("scanByte", error.UnknownToken);
            return error.UnknownToken;
        },
    }
    self.line_position += 1;
}

// TODO: make number scanning more sophisticated (e.g. handle 01 number)
fn scanNumber(self: *Scanner) !void {
    const start = self.r.seek - 1;
    var float: bool = false;

    while (true) {
        const byte = try self.r.peekByte();
        if (byte == '.') {
            float = true;
        } else if (!std.ascii.isDigit(byte)) {
            const token: Token = if (float) .{ .f64 = self.src[start..self.r.seek] } else .{ .i64 = self.src[start..self.r.seek] };
            try self.addToken(token);
            break;
        }
        self.r.toss(1);
    }
}

fn scanStringLiteral(self: *Scanner) !void {
    if (try self.r.takeDelimiter('"')) |string| {
        try self.addToken(.{ .string = string });
    } else {
        self.reportError("scanString", error.UnquottedString);
        return error.UnquottedString;
    }
}

fn scanLiteralOrKeyword(self: *Scanner) !void {
    const start = self.r.seek - 1;

    while (true) {
        const byte = try self.r.peekByte();
        if (!std.ascii.isAlphanumeric(byte) and byte != '_') {
            try self.classifyAndAppend(self.src[start..self.r.seek]);
            break;
        }
        self.r.toss(1);
    }
}

fn classifyAndAppend(self: *Scanner, buffer: []const u8) !void {
    var token: Token = undefined;

    if (std.mem.eql(u8, buffer, "if")) {
        token = .{ .@"if" = buffer };
    } else if (std.mem.eql(u8, buffer, "else")) {
        token = .{ .@"else" = buffer };
    } else if (std.mem.eql(u8, buffer, "while")) {
        token = .{ .@"while" = buffer };
    } else if (std.mem.eql(u8, buffer, "or")) {
        token = .{ .@"or" = buffer };
    } else if (std.mem.eql(u8, buffer, "xor")) {
        token = .{ .xor = buffer };
    } else if (std.mem.eql(u8, buffer, "and")) {
        token = .{ .@"and" = buffer };
    } else if (std.mem.eql(u8, buffer, "not")) {
        token = .{ .not = buffer };
    } else if (std.mem.eql(u8, buffer, "for")) {
        token = .{ .@"for" = buffer };
    } else if (std.mem.eql(u8, buffer, "nil")) {
        token = .{ .nil = buffer };
    } else if (std.mem.eql(u8, buffer, "true")) {
        token = .{ .true = buffer };
    } else if (std.mem.eql(u8, buffer, "false")) {
        token = .{ .false = buffer };
    } else if (std.mem.eql(u8, buffer, "print")) {
        token = .{ .print = buffer };
    } else {
        token = .{ .identifier = buffer };
    }

    try self.addToken(token);
}
