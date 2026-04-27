const std = @import("std");
const Context = @import("context.zig").Context;

pub fn writeName(ctx: *Context, writer: *std.Io.Writer, name_id: usize) !void {
    const n_opt = ctx.names.items[name_id];
    if (n_opt) |name| {
        switch (name) {
            .str => |s| {
                if (s.pre != 0) {
                    try writeName(ctx, writer, s.pre);
                    try writer.writeByte('.');
                }
                try writer.writeAll(s.str);
            },
            .num => |n| {
                if (n.pre != 0) {
                    try writeName(ctx, writer, n.pre);
                    try writer.writeByte('.');
                }
                try writer.print("{d}", .{n.i});
            },
        }
    } else { // TODO: Fail here
        return;
    }
}

pub fn resolveNameAlloc(ctx: *Context, gpa: std.mem.Allocator, name_id: usize) ![]u8 {
    var buffer: std.Io.Writer.Allocating = .init(gpa);
    errdefer buffer.deinit();

    const writer = &buffer.writer;

    try writeName(ctx, writer, name_id);
    var array_list = buffer.toArrayList();

    return array_list.toOwnedSlice(gpa);
}

pub fn writeLevel(ctx: *Context, writer: *std.Io.Writer, level_id: usize) !void {
    if (level_id == 0) {
        try writer.writeAll("0");
        return;
    }
    const level_opt = ctx.levels.items[level_id];
    if (level_opt) |level| {
        switch (level) {
            .param => |id| {
                try writeName(ctx, writer, id);
            },
            .max => |lr| {
                try writer.writeAll("max(");
                try writeLevel(ctx, writer, lr[0]);
                try writer.writeAll(", ");
                try writeLevel(ctx, writer, lr[1]);
                try writer.writeAll(")");
            },
            .imax => |lr| {
                try writer.writeAll("imax(");
                try writeLevel(ctx, writer, lr[0]);
                try writer.writeAll(", ");
                try writeLevel(ctx, writer, lr[1]);
                try writer.writeAll(")");
            },
            .succ => |prev| {
                try writer.writeAll("succ(");
                try writeLevel(ctx, writer, prev);
                try writer.writeAll(")");
            },
        }
    } else { // TODO: Fail here
        return;
    }
}

pub fn writeExpr(ctx: *Context, writer: *std.Io.Writer, expr_id: usize) !void {
    const expr_opt = ctx.exprs.items[expr_id];

    if (expr_opt) |expr| {
        switch (expr) {
            .bvar => |db_idx| {
                try writer.print("#{d}", .{db_idx});
            },
            .sort => |level_id| {
                try writeLevel(ctx, writer, level_id);
            },
            else => {
                try writer.print("Haven't figured out how to print these guys yet {}", .{expr});
            },
        }
    } else { // TODO: Fail here
        return;
    }
}
