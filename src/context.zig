const std = @import("std");
const data = @import("data.zig");
const writers = @import("writers.zig");

pub const Error = error{
    InvalidName,
    InvalidLevel,
    InvalidExpr,
    InvalidDecl,
};

pub const Context = struct {
    names: std.ArrayList(?data.Name),
    levels: std.ArrayList(?data.Level),
    exprs: std.ArrayList(?data.Expr),
    decls: std.ArrayList(?data.Decl),
    nameMap: std.StringHashMap(usize),

    pub fn init(allocator: std.mem.Allocator) !Context {
        var names: std.ArrayList(?data.Name) = .empty;
        try names.append(allocator, null);
        var levels: std.ArrayList(?data.Level) = .empty;
        try levels.append(allocator, null);
        const exprs: std.ArrayList(?data.Expr) = .empty;
        const decls: std.ArrayList(?data.Decl) = .empty;
        const nameMap: std.StringHashMap(usize) = .init(allocator);

        return Context{
            .names = names,
            .levels = levels,
            .exprs = exprs,
            .decls = decls,
            .nameMap = nameMap,
        };
    }

    pub fn deinit(self: *Context, gpa: std.mem.Allocator) void {
        self.names.deinit(gpa);
        self.levels.deinit(gpa);
        self.exprs.deinit(gpa);
        self.decls.deinit(gpa);
    }

    pub fn populateNameMap(self: *Context, gpa: std.mem.Allocator) !void {
        for (0..self.names.items.len) |name_id| {
            if (name_id == 0) {
                try self.nameMap.put("_root_", 0);
            } else {
                const resolved_name = try writers.resolveNameAlloc(self, gpa, name_id);
                try self.nameMap.put(resolved_name, name_id);
            }
        }
    }
};

pub fn containsBvar(bvar: usize, body: data.Expr, ctx: *Context) bool {
    switch (body) {
        .bvar => |bvar_idx| {
            return bvar == bvar_idx;
        },
        .app => |app_data| {
            const fn_expr = (ctx.getExpr(app_data.@"fn") catch return false).?;
            const arg_expr = ctx.getExpr(app_data.arg).?;
            return containsBvar(bvar, fn_expr, ctx) or containsBvar(bvar, arg_expr, ctx);
        },
        .lam => |lam_data| {
            const type_expr = ctx.getExpr(lam_data.type).?;
            const body_expr = ctx.getExpr(lam_data.body).?;
            return containsBvar(bvar, type_expr, ctx) or containsBvar(bvar + 1, body_expr, ctx);
        },
        .forallE => |forall_data| {
            const type_expr = ctx.getExpr(forall_data.type).?;
            const body_expr = ctx.getExpr(forall_data.body).?;
            return containsBvar(bvar, type_expr, ctx) or containsBvar(bvar + 1, body_expr, ctx);
        },
        .letE => |let_data| {
            const type_expr = ctx.getExpr(let_data.type).?;
            const value_expr = ctx.getExpr(let_data.value).?;
            const body_expr = ctx.getExpr(let_data.body).?;
            return containsBvar(bvar, type_expr, ctx) or
                containsBvar(bvar, value_expr, ctx) or
                containsBvar(bvar + 1, body_expr, ctx);
        },
        .proj => |proj_data| {
            const struct_expr = ctx.getExpr(proj_data.@"struct").?;
            return containsBvar(bvar, struct_expr, ctx);
        },
        .mdata => |m_data| {
            return containsBvar(bvar, ctx.getExpr(m_data.expr).?, ctx);
        },
        else => return false,
    }
}

pub fn arrowLike(expr: data.Expr, ctx: *Context) !bool {
    switch (expr) {
        .forallE => |forall_data| {
            if (try ctx.getExpr(forall_data.body)) |body| {
                return !containsBvar(0, body, ctx);
            } else {
                return false;
            }
        },
        else => return false,
    }
}

pub fn numLike(level_id: usize, ctx: *Context) !?usize {
    if (level_id == 0) return 0;

    const level = (try ctx.getLevel(level_id)).?;

    switch (level) {
        .succ => |inner| {
            if (try ctx.getLevel(inner)) |inner_id| {
                return numLike(inner_id, ctx);
            } else {
                return null;
            }
        },
        else => return null,
    }
}
