const std = @import("std");
const data = @import("data.zig");

pub const Context = struct {
    names: std.ArrayList(data.Name) = .empty,
    levels: std.ArrayList(data.Level) = .empty,
    exprs: std.ArrayList(data.Expr) = .empty,
    decls: std.ArrayList(data.Decl) = .empty,

    pub fn deinit(self: *Context, gpa: std.mem.Allocator) void {
        self.names.deinit(gpa);
        self.levels.deinit(gpa);
        self.exprs.deinit(gpa);
        self.decls.deinit(gpa);
    }
};
