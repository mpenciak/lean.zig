const std = @import("std");
const data = @import("data.zig");
const writers = @import("writers.zig");

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

        return Context{ .names = names, .levels = levels, .exprs = exprs, .decls = decls, .nameMap = nameMap };
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
