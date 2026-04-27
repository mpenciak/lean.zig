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

pub fn writeName(ctx: *Context, writer: anytype, name_id: u32) !void {
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
    } else {
        return;
    }
}

pub fn resolveNameAlloc(ctx: *Context, gpa: std.mem.Allocator, name_id: u32) ![]u8 {
    var buffer: std.Io.Writer.Allocating = .init(gpa);
    errdefer buffer.deinit();

    const writer = &buffer.writer;

    try writeName(ctx, writer, name_id);
    var array_list = buffer.toArrayList();

    return array_list.toOwnedSlice(gpa);
}

pub fn printNames(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    defer stdout.close(io);
    var buffer: [4096]u8 = undefined;
    var writer = stdout.writer(io, &buffer);
    const inter = &writer.interface;

    for (0..ctx.names.items.len) |name_id| {
        try writeName(ctx, inter, @intCast(name_id));
        try inter.writeAll("\n");
    }

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const last_name = try resolveNameAlloc(ctx, allocator, 1);
    try inter.print("one last one: {s}\n", .{last_name});
    try inter.flush();
}
