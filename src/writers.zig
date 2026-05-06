const std = @import("std");
const Writer = std.Io.Writer;

const Context = @import("context.zig").Context;
const BinderInfo = @import("data.zig").BinderInfo;

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

pub const Precedence = enum {
    free,
    arg,
};

pub const NamingEnv = struct {
    local: []usize,
    parent: ?*const NamingEnv,

    pub fn resolve(self: *const NamingEnv, db_idx: usize) ?usize {
        if (db_idx >= self.local.len) {
            if (self.parent) |parent| {
                return parent.resolve(db_idx - self.local.len);
            } else {
                return null;
            }
        } else {
            return self.local[self.local.len - db_idx - 1];
        }
    }
};

pub const ExprFormatter = struct {
    ctx: *Context,
    expr_id: usize,
    prec: Precedence = .free,
    names: ?*const NamingEnv = null,

    pub fn format(self: ExprFormatter, writer: *Writer) Writer.Error!void {
        const expr_opt = self.ctx.exprs.items[self.expr_id];

        if (expr_opt) |expr| {
            switch (expr) {
                .bvar => |db_idx| {
                    if (self.names) |name_ctx| {
                        if (name_ctx.resolve(db_idx)) |name_idx| {
                            try fmtName(self.ctx, name_idx).format(writer);
                            return;
                        }
                    }
                    // Fall back to de bruijn printing for free variables
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

                    const level_list = fmtCommaSep(usize, fmtLevel, self.ctx, const_data.us);
                    try writer.print("{[name]f}.{{{[levels]f}}}", .{ .name = name, .levels = level_list });
                },
                .app => |app_data| {
                    if (self.prec == .arg) {
                        try writer.writeByte('(');
                    }
                    const fn_part = fmtExpr(
                        self.ctx,
                        app_data.@"fn",
                        .free,
                        self.names,
                    );
                    const arg_part = fmtExpr(
                        self.ctx,
                        app_data.arg,
                        .arg,
                        self.names,
                    );

                    try writer.print("{[fn_part]f} {[arg_part]f}", .{ .fn_part = fn_part, .arg_part = arg_part });

                    if (self.prec == .arg) {
                        try writer.writeByte(')');
                    }
                },
                .lam => |lam_data| try self.formatForAllLambda(writer, lam_data, true),
                .forallE => |forall_data| try self.formatForAllLambda(writer, forall_data, false),
                else => {
                    try writer.print("(TODO: {})", .{expr});
                },
            }
        } else { // TODO: Fail here
            return;
        }
    }

    fn formatForAllLambda(
        self: ExprFormatter,
        writer: *Writer,
        data: anytype,
        comptime is_lambda: bool,
    ) Writer.Error!void {
        if (self.prec == .arg) {
            try writer.writeByte('(');
        }

        try writer.writeAll(if (is_lambda) "fun " else "∀ ");

        try writeBinder(
            fmtName(self.ctx, data.name),
            fmtExpr(self.ctx, data.type, .free, self.names),
            data.binderInfo,
            writer,
        );

        var local_names: [64]usize = undefined;
        var bound_count: usize = 0;
        local_names[bound_count] = data.name;
        bound_count += 1;

        var body_idx = data.body;

        while (self.ctx.exprs.items[body_idx]) |body_expr| {
            const inner_opt = if (is_lambda)
                switch (body_expr) {
                    .lam => |d| d,
                    else => null,
                }
            else switch (body_expr) {
                .forallE => |d| d,
                else => null,
            };

            const new_names: NamingEnv = .{
                .local = local_names[0..bound_count],
                .parent = self.names,
            };

            if (inner_opt) |inner_data| {
                try writeBinder(
                    fmtName(self.ctx, inner_data.name),
                    fmtExpr(self.ctx, inner_data.type, .free, &new_names),
                    inner_data.binderInfo,
                    writer,
                );
                local_names[bound_count] = inner_data.name;
                bound_count += 1;
                body_idx = inner_data.body;
            } else {
                const sep = if (is_lambda) "=> " else ", ";
                try writer.print("{s}{f}", .{
                    sep,
                    fmtExpr(self.ctx, body_idx, .free, &new_names),
                });
                break;
            }
        }

        if (self.prec == .arg) {
            try writer.writeByte(')');
        }
    }
};

fn writeBinder(
    namefmt: NameFormatter,
    typefmt: ExprFormatter,
    binder: BinderInfo,
    writer: *Writer,
) Writer.Error!void {
    try writer.print("{[open]c}{[name]f} : {[typefmt]f}{[close]c} ", .{
        .open = binder.opening(),
        .name = namefmt,
        .typefmt = typefmt,
        .close = binder.closing(),
    });
}

pub fn fmtExpr(ctx: *Context, expr_id: usize, prec: Precedence, names: ?*const NamingEnv) ExprFormatter {
    return .{
        .ctx = ctx,
        .expr_id = expr_id,
        .prec = prec,
        .names = names,
    };
}

pub fn CommaSepFormatter(comptime T: type, comptime fmt_fn: anytype) type {
    return struct {
        ctx: *Context,
        items: []const T,

        pub fn format(self: @This(), writer: *Writer) Writer.Error!void {
            if (self.items.len == 1) {
                try fmt_fn(self.ctx, self.items[0]).format(writer);
            } else if (self.items.len > 1) {
                try fmt_fn(self.ctx, self.items[0]).format(writer);
                for (self.items[1..]) |item| {
                    try writer.writeAll(", ");
                    try fmt_fn(self.ctx, item).format(writer);
                }
            } else {
                return;
            }
        }
    };
}

pub fn fmtCommaSep(
    comptime T: type,
    comptime fmt_fn: anytype,
    ctx: *Context,
    items: []const T,
) CommaSepFormatter(T, fmt_fn) {
    return .{ .ctx = ctx, .items = items };
}

pub fn SpaceSepFormatter(comptime T: type, comptime fmt_fn: anytype) type {
    return struct {
        ctx: *Context,
        items: []const T,

        pub fn format(self: @This(), writer: *Writer) Writer.Error!void {
            if (self.items.len == 1) {
                try fmt_fn(self.ctx, self.items[0]).format(writer);
            } else if (self.items.len > 1) {
                try fmt_fn(self.ctx, self.items[0]).format(writer);
                for (self.items[1..]) |item| {
                    try writer.writeByte(' ');
                    try fmt_fn(self.ctx, item).format(writer);
                }
            } else {
                return;
            }
        }
    };
}
