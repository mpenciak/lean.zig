const std = @import("std");
const Context = @import("context.zig").Context;
const writers = @import("writers.zig");

pub fn printNames(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var writer = stdout.writer(io, &buffer);
    const inter = &writer.interface;

    for (0..ctx.names.items.len) |name_id| {
        try writers.writeName(ctx, inter, @intCast(name_id));
        try inter.writeAll("\n");
    }
    try inter.flush();
}

pub fn printLevels(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var writer = stdout.writer(io, &buffer);
    const inter = &writer.interface;

    for (0..ctx.levels.items.len) |name_id| {
        try writers.writeLevel(ctx, inter, @intCast(name_id));
        try inter.writeAll("\n");
    }
    try inter.flush();
}

pub fn printExprs(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var writer = stdout.writer(io, &buffer);
    const inter = &writer.interface;

    for (0..ctx.exprs.items.len) |name_id| {
        try writers.writeExpr(ctx, inter, @intCast(name_id));
        try inter.writeAll("\n");
    }
    try inter.flush();
}
