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
                else => {
                    try writer.print("TODO: {}", .{expr});
                },
            }
        } else { // TODO: Fail here
            return;
        }
    }
};

pub fn fmtExpr(ctx: *Context, expr_id: usize) ExprFormatter {
    return .{ .ctx = ctx, .expr_id = expr_id };
}
