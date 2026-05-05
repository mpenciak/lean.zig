const std = @import("std");
const Writer = std.Io.Writer;

const Context = @import("context.zig").Context;

pub const NameFormatter = struct {
    ctx: *Context,
    name_id: usize,

    pub fn format(self: NameFormatter, writer: *Writer) Writer.Error!void {
        if (self.name_id == 0) {
            try writer.writeAll("_root_");
        }
        const n_opt = self.ctx.names.items[self.name_id];
        if (n_opt) |name| {
            switch (name) {
                .str => |s| {
                    if (s.pre != 0) {
                        try fmtName(self.ctx, s.pre).format(writer);
                        try writer.writeByte('.');
                    }
                    try writer.writeAll(s.str);
                },
                .num => |n| {
                    if (n.pre != 0) {
                        try fmtName(self.ctx, n.pre).format(writer);
                        try writer.writeByte('.');
                    }
                    try writer.print("{d}", .{n.i});
                },
            }
        } else { // TODO: Fail here
            return;
        }
    }
};

pub fn resolveNameAlloc(ctx: *Context, gpa: std.mem.Allocator, name_id: usize) ![]u8 {
    var buffer: Writer.Allocating = .init(gpa);
    errdefer buffer.deinit();

    const writer = &buffer.writer;

    try fmtName(ctx, name_id).format(writer);
    var array_list = buffer.toArrayList();

    return array_list.toOwnedSlice(gpa);
}

pub fn fmtName(ctx: *Context, name_id: usize) NameFormatter {
    return .{ .ctx = ctx, .name_id = name_id };
}

pub const LevelFormatter = struct {
    ctx: *Context,
    level_id: usize,

    pub fn format(self: LevelFormatter, writer: *Writer) Writer.Error!void {
        if (self.level_id == 0) {
            try writer.writeByte('0');
        }
        const level_opt = self.ctx.levels.items[self.level_id];
        if (level_opt) |level| {
            switch (level) {
                .param => |name_id| {
                    try fmtName(self.ctx, name_id).format(writer);
                },
                .max => |lr| {
                    const left_fmt = fmtLevel(self.ctx, lr[0]);
                    const right_fmt = fmtLevel(self.ctx, lr[1]);
                    try writer.print("max({f}, {f})", .{ left_fmt, right_fmt });
                },
                .imax => |lr| {
                    const left_fmt = fmtLevel(self.ctx, lr[0]);
                    const right_fmt = fmtLevel(self.ctx, lr[1]);
                    try writer.print("imax({f}, {f})", .{ left_fmt, right_fmt });
                },
                .succ => |prev| {
                    const prev_fmt = fmtLevel(self.ctx, prev);
                    try writer.print("succ({f})", .{prev_fmt});
                },
            }
        } else { // TODO: fail here
            return;
        }
    }
};

pub fn fmtLevel(ctx: *Context, level_id: usize) LevelFormatter {
    return .{ .ctx = ctx, .level_id = level_id };
}

pub const ExprFormatter = struct {
    ctx: *Context,
    gpa: std.mem.Allocator,
    expr_id: usize,

    pub fn format(self: ExprFormatter, writer: *Writer) Writer.Error!void {
        const expr_opt = self.ctx.exprs.items[self.expr_id];

        if (expr_opt) |expr| {
            switch (expr) {
                .bvar => |db_idx| {
                    try writer.print("#{d}", .{db_idx});
                },
                .sort => |level_id| {
                    try writer.print("Sort {f}", .{fmtLevel(self.ctx, level_id)});
                },
                .@"const" => |const_data| {
                    const name = fmtName(self.ctx, const_data.name);
                    if (const_data.us.len == 0) {
                        try name.format(writer);
                        return;
                    }
                    const levels: []LevelFormatter = blk: {
                        var levels: std.ArrayList(LevelFormatter) = .empty;
                        for (const_data.us) |u| {
                            levels.append(self.gpa, fmtLevel(self.ctx, u)) catch return Writer.Error.WriteFailed;
                        }
                        const owned_levels = levels.toOwnedSlice(self.gpa) catch return Writer.Error.WriteFailed;
                        break :blk owned_levels;
                    };
                    const level_formatter: CommaSepFormatter(LevelFormatter) = .init(levels);
                    try writer.print("{[name]f}.{{{[levels]f}}}", .{ .name = name, .levels = level_formatter });
                    self.gpa.free(levels);
                },

                else => {
                    try writer.print("TODO: {}", .{expr});
                },
            }
        } else { // TODO: Fail here
            return;
        }
    }
};

pub fn fmtExpr(ctx: *Context, gpa: std.mem.Allocator, expr_id: usize) ExprFormatter {
    return .{ .ctx = ctx, .gpa = gpa, .expr_id = expr_id };
}

pub fn CommaSepFormatter(T: type) type {
    return struct {
        items: []T,

        pub fn init(data: []T) @This() {
            return .{ .items = data };
        }

        pub fn format(self: @This(), writer: *Writer) Writer.Error!void {
            if (self.items.len == 1) {
                try self.items[0].format(writer);
            } else if (self.items.len > 1) {
                try self.items[0].format(writer);
                for (self.items[1..]) |item| {
                    try writer.writeAll(", ");
                    try item.format(writer);
                }
            } else {
                return;
            }
        }
    };
}

pub fn SpaceSepFormatter(T: type) type {
    return struct {
        items: []T,

        pub fn init(data: []T) @This() {
            return .{ .items = data };
        }

        pub fn format(self: @This(), writer: *Writer) Writer.Error!void {
            _ = self;
            try writer.writeAll("HAHAHAHAHAHAHA");
        }
    };
}
