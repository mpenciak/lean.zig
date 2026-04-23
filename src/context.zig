const std = @import("std");
const data = @import("data.zig");

pub const Context = struct {
    names: std.ArrayList(?data.Name),
    levels: std.ArrayList(?data.Level),
    exprs: std.ArrayList(?data.Expr),
    decls: std.ArrayList(?data.Decl),

    pub fn init(allocator: std.mem.Allocator) !Context {
        var names: std.ArrayList(?data.Name) = .empty;
        try names.append(allocator, null);
        var levels: std.ArrayList(?data.Level) = .empty;
        try levels.append(allocator, null);
        const exprs: std.ArrayList(?data.Expr) = .empty;
        const decls: std.ArrayList(?data.Decl) = .empty;

        return Context{ .names = names, .levels = levels, .exprs = exprs, .decls = decls };
    }

    pub fn deinit(self: *Context, gpa: std.mem.Allocator) void {
        self.names.deinit(gpa);
        self.levels.deinit(gpa);
        self.exprs.deinit(gpa);
        self.decls.deinit(gpa);
    }
};
