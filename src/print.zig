const std = @import("std");
const Context = @import("context.zig").Context;
const writers = @import("writers.zig");

pub fn printNames(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var buffered = stdout.writer(io, &buffer);
    const writer = &buffered.interface;

    for (0..ctx.names.items.len) |name_id| {
        try writers.fmtName(ctx, name_id).format(writer);
        try writer.writeAll("\n");
    }
    try writer.flush();
}

pub fn printLevels(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var buffered = stdout.writer(io, &buffer);
    const writer = &buffered.interface;

    for (0..ctx.levels.items.len) |level_id| {
        try writers.fmtLevel(ctx, level_id).format(writer);
        try writer.writeAll("\n");
    }
    try writer.flush();
}

pub fn printExprs(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var buffered = stdout.writer(io, &buffer);
    const writer = &buffered.interface;

    for (0..ctx.exprs.items.len) |expr_id| {
        try writers.fmtExpr(
            ctx,
            expr_id,
            .free,
            null,
        ).format(writer);
        try writer.writeAll("\n");
    }
    try writer.flush();
}

pub fn printDecls(ctx: *Context, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var buffered = stdout.writer(io, &buffer);
    const writer = &buffered.interface;

    for (0..ctx.decls.items.len) |decl_id| {
        try writers.fmtDecl(
            ctx,
            decl_id,
        ).format(writer);
        try writer.writeAll("\n");
    }
    try writer.flush();
}
