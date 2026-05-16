const std = @import("std");
const Writer = std.Io.Writer;

const context = @import("context.zig");
const Context = context.Context;

const data_import = @import("data.zig");
const Expr = data_import.Expr;
const BinderInfo = data_import.BinderInfo;
const Inductive = data_import.Inductive;
const InductiveVal = data_import.InductiveVal;
const ConstructorVal = data_import.ConstructorVal;
const RecursorVal = data_import.RecursorVal;

pub const NameFormatter = struct {
    ctx: *Context,
    name_id: usize,

    pub fn format(self: NameFormatter, writer: *Writer) Writer.Error!void {
        const name = self.ctx.names.items[self.name_id];
        switch (name) {
            .root => try writer.writeAll("_root_"),
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
    }
};

pub fn fmtName(ctx: *Context, name_id: usize) NameFormatter {
    return .{ .ctx = ctx, .name_id = name_id };
}

pub fn resolveNameAlloc(ctx: *Context, gpa: std.mem.Allocator, name_id: usize) ![]u8 {
    var buffer: Writer.Allocating = .init(gpa);
    errdefer buffer.deinit();

    const writer = &buffer.writer;

    try fmtName(ctx, name_id).format(writer);
    var array_list = buffer.toArrayList();

    return array_list.toOwnedSlice(gpa);
}

pub const LevelFormatter = struct {
    ctx: *Context,
    level_id: usize,

    pub fn format(self: LevelFormatter, writer: *Writer) Writer.Error!void {
        const level = self.ctx.levels.items[self.level_id];
        if (context.numLike(self.level_id, self.ctx)) |univ| {
            try writer.printInt(univ, 10, .lower, .{});
            return;
        }

        switch (level) {
            .zero => try writer.writeByte('0'),
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
        const expr = self.ctx.exprs.items[self.expr_id];
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
                if (context.numLike(level_id, self.ctx)) |univ| {
                    if (univ == 0) {
                        try writer.writeAll("Prop");
                    } else if (univ == 1) {
                        try writer.writeAll("Type");
                    } else {
                        try writer.print("Type {d}", .{univ - 1});
                    }
                    return;
                }

                if (self.ctx.levels.items[level_id] == .succ) {
                    const inner_id = self.ctx.levels.items[level_id].succ;
                    try writer.print("Type {f}", .{fmtLevel(self.ctx, inner_id)});
                } else {
                    try writer.print("Type {f}", .{fmtLevel(self.ctx, level_id)});
                }
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
            .letE => |let_data| {
                const keyword = if (let_data.nondep) "let" else "have";
                const nameFmt = fmtName(self.ctx, let_data.name);
                const typeFmt = fmtExpr(self.ctx, let_data.type, .free, self.names);
                const valueFmt = fmtExpr(self.ctx, let_data.value, .free, self.names);
                const bodyFmt = fmtExpr(self.ctx, let_data.body, .free, self.names);

                try writer.print("{[keyword]s} {[name]f} : {[typ]f} := {[val]f}\n{[body]f}", .{
                    .keyword = keyword,
                    .name = nameFmt,
                    .typ = typeFmt,
                    .val = valueFmt,
                    .body = bodyFmt,
                });
            },
            .proj => |proj_data| {
                const structfmt = fmtExpr(self.ctx, proj_data.@"struct", self.prec, self.names);
                try writer.print("{f}.{}", .{ structfmt, proj_data.idx }); // TODO: This is the best we can do for now
            },
            .natVal => |val| try writer.writeAll(val),
            .strVal => |val| try writer.writeAll(val),
            .mdata => |inner| try fmtExpr(self.ctx, inner.expr, self.prec, self.names).format(writer),
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

        if (is_lambda) {
            try writer.writeAll("fun ");
        } else {
            const forall_expr: Expr = .{ .forallE = data };

            if (context.arrowLike(forall_expr, self.ctx)) {
                const typeFmt = fmtExpr(self.ctx, data.type, .free, self.names);
                const bodyFmt = fmtExpr(self.ctx, data.body, .free, self.names);
                // TODO make this branch right
                try writer.print("{f} -> {f}", .{ typeFmt, bodyFmt });
                return;
            } else {
                try writer.writeAll("∀ ");
            }
        }

        try writeBinder(
            fmtName(self.ctx, data.name),
            fmtExpr(self.ctx, data.type, .free, self.names),
            data.binderInfo,
            writer,
        );

        // TODO: Assumes names are < 64 long,
        // should come back to this
        var local_names: [64]usize = undefined;
        var bound_count: usize = 0;
        local_names[bound_count] = data.name;
        bound_count += 1;

        var body_idx = data.body;

        while (true) {
            const body_expr = self.ctx.exprs.items[body_idx];
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

pub const DeclFormatter = struct {
    ctx: *Context,
    decl_id: usize,

    pub fn format(self: DeclFormatter, writer: *Writer) Writer.Error!void {
        const decl = self.ctx.decls.items[self.decl_id];

        switch (decl) {
            .axiom => |data| {
                if (data.isUnsafe) {
                    try writer.writeAll("unsafe ");
                }
                try writer.writeAll("axiom ");
                try fmtName(self.ctx, data.name).format(writer);
                if (data.levelParams.len > 0) {
                    try writer.writeAll(".{");
                    try fmtCommaSep(usize, fmtName, self.ctx, data.levelParams).format(writer);
                    try writer.writeByte('}');
                }

                try writer.writeAll(" : ");

                try fmtExpr(self.ctx, data.type, .free, null).format(writer);
            },
            .def => |data| {
                switch (data.safety) {
                    .unsafe => try writer.writeAll("unsafe "),
                    .partial => try writer.writeAll("partial "),
                    .safe => {},
                }
                const keyword = if (data.hints == .abbrev) "abbrev" else "def";
                try self.writeSig(writer, keyword, data.name, data.levelParams, data.type, data.value);
            },
            .@"opaque" => |data| {
                if (data.isUnsafe) try writer.writeAll("unsafe ");
                try self.writeSig(writer, "opaque", data.name, data.levelParams, data.type, data.value);
            },
            .thm => |data| {
                try self.writeSig(writer, "theorem", data.name, data.levelParams, data.type, data.value);
            },
            .quot => |data| {
                // Quotient declarations are surfaced as `opaque` since they have no body.
                try self.writeSig(writer, "opaque", data.name, data.levelParams, data.type, null);
            },
            .inductive => |ind_data| {
                const is_mutual = ind_data.types.len > 1;

                if (is_mutual) try writer.writeAll("mutual\n");

                var ctor_idx: usize = 0;
                for (ind_data.types) |ind_val| {
                    try self.writeIndSig(writer, &ind_val);
                    for (0..ind_val.ctors.len) |inner_idx| {
                        const ctor_val = ind_data.ctors[ctor_idx];
                        std.debug.assert(ctor_val.cidx == inner_idx);
                        try self.writeCtor(writer, &ctor_val);
                        ctor_idx += 1;
                    }
                }

                if (is_mutual) try writer.writeAll("end\n");
            },
        }
    }

    fn writeIndSig(
        self: DeclFormatter,
        writer: *Writer,
        ind_val: *const InductiveVal,
    ) Writer.Error!void {
        const name_fmt = fmtName(self.ctx, ind_val.name);
        try writer.print("inductive {f}", .{name_fmt});
        if (ind_val.levelParams.len > 0) {
            const level_fmt = fmtCommaSep(usize, fmtName, self.ctx, ind_val.levelParams);
            try writer.print(".{{{f}}}", .{level_fmt});
        }
        try writer.writeByte(' ');

        std.debug.assert(ind_val.numParams + ind_val.numIndices < 64);
        var name_data: [64]usize = undefined;
        var tp_idx = ind_val.type;
        var tp = self.ctx.getExpr(tp_idx).?;

        // This is where we write the params
        for (0..ind_val.numParams) |binder_idx| {
            name_data[binder_idx] = tp.forallE.name;
            const name_env: NamingEnv = .{ .local = name_data[0..binder_idx], .parent = null };
            try writeBinder(
                fmtName(self.ctx, tp.forallE.name),
                fmtExpr(self.ctx, tp.forallE.type, .free, &name_env),
                tp.forallE.binderInfo,
                writer,
            );

            tp_idx = tp.forallE.body;
            tp = self.ctx.getExpr(tp_idx).?;
        }

        try writer.writeAll(": ");

        const name_env: NamingEnv = .{ .local = name_data[0..ind_val.numParams], .parent = null };
        // This is where we write the indices
        for (ind_val.numParams..ind_val.numParams + ind_val.numIndices) |_| {
            const fmt_expr = fmtExpr(self.ctx, tp.forallE.type, .free, &name_env);

            try writer.print("{f} -> ", .{fmt_expr});
            tp_idx = tp.forallE.body;
            tp = self.ctx.getExpr(tp_idx).?;
        }

        try fmtExpr(self.ctx, tp_idx, .free, &name_env).format(writer);
        try writer.writeAll("\n");
    }

    fn writeCtor(self: DeclFormatter, writer: *Writer, ctor_val: *const ConstructorVal) Writer.Error!void {
        try self.writeSig(writer, "|", ctor_val.name, ctor_val.levelParams, ctor_val.type, null);
    }

    // TODO: We already have the recursors in the environment, so maybe we don't need to print them
    //       (but we will typecheck them?)
    // fn writeRec(self: DeclFormatter, ind_data: *const Inductive, rec_val: *const RecursorVal) Writer.Error!void {
    //     _ = self;
    //     _ = ind_data;
    //     _ = rec_val;
    // }

    fn writeSig(
        self: DeclFormatter,
        writer: *Writer,
        keyword: []const u8,
        name_id: usize,
        levelParams: []const usize,
        type_id: usize,
        value_id: ?usize,
    ) Writer.Error!void {
        try writer.print("{s} {f}", .{ keyword, fmtName(self.ctx, name_id) });
        if (levelParams.len > 0) {
            try writer.print(".{{{f}}}", .{fmtCommaSep(usize, fmtName, self.ctx, levelParams)});
        }
        try writer.writeByte(' ');

        var local_names: [64]usize = undefined;
        var num_binders: usize = 0;
        var tp_idx = type_id;
        var tp = self.ctx.getExpr(tp_idx).?;

        while (tp.forallLamPayload()) |inner_data| {
            const name_env: NamingEnv = .{ .local = local_names[0..num_binders], .parent = null };
            try writeBinder(
                fmtName(self.ctx, inner_data.name),
                fmtExpr(self.ctx, inner_data.type, .free, &name_env),
                inner_data.binderInfo,
                writer,
            );

            local_names[num_binders] = inner_data.name;
            num_binders += 1;

            tp_idx = inner_data.body;
            tp = self.ctx.getExpr(tp_idx).?;
        }

        const name_env: NamingEnv = .{ .local = local_names[0..num_binders], .parent = null };

        try writer.print(": {f}", .{fmtExpr(self.ctx, tp_idx, .free, &name_env)});

        if (value_id) |v| {
            var value = v;
            while (self.ctx.getExpr(value).? == .lam) {
                value = self.ctx.getExpr(value).?.lam.body;
            }
            try writer.print(" := {f}", .{fmtExpr(self.ctx, value, .free, &name_env)});
        }
    }
};

pub fn fmtDecl(ctx: *Context, decl_id: usize) DeclFormatter {
    return .{ .ctx = ctx, .decl_id = decl_id };
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
