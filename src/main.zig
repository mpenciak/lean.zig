const std = @import("std");
const json = std.json;
const root = @import("lean_zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();

    const arg0 = args.next().?; // path to executable
    const file_path = if (args.next()) |arg| arg else {
        std.debug.print("Usage: {s} <path>\n", .{arg0});
        return;
    };

    const file = try std.Io.Dir.cwd().openFile(io, file_path, .{});
    defer file.close(io);

    var internal_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &internal_buffer);
    const reader = &file_reader.interface;

    var idx: usize = 0;

    const first_line = (try reader.takeDelimiter('\n')).?;

    const obj =
        try json.parseFromSlice(root.meta.Header, gpa, first_line, .{});
    defer obj.deinit();

    var name_context: root.context.NameContext = try .init(gpa);
    defer name_context.deinit(gpa);
    var level_context: root.context.LevelContext = try .init(gpa);
    defer level_context.deinit(gpa);

    while (try reader.takeDelimiter('\n')) |line| : (idx += 1) {
        const parsed_obj =
            try json.parseFromSlice(json.Value, gpa, line, .{});
        defer parsed_obj.deinit();

        const kind = findKind(parsed_obj.value.object).?;
        std.debug.print("{}\n", .{kind});
        // const line_obj = parsed_obj.value;
        // const line_obj_obj = line_obj.object;
        // const keys = line_obj_obj.ge
        // const strnameraw =
        //     json.parseFromValue(StrName, gpa, line_obj, .{}) catch continue;
        // defer strnameraw.deinit();
        // std.debug.print("successfully parsed {}\n", .{strnameraw.value});
    }
}

// fn parseLine(line: []u8, allocator: std.mem.Allocator, context: *root.context.Context) !void {}

fn findKind(obj: json.ObjectMap) ?LineKind {
    var it = obj.iterator();
    while (it.next()) |entry| {
        if (std.meta.stringToEnum(LineKind, entry.key_ptr.*)) |k| return k;
    }
    return null;
}

const LineKind = enum {
    // Names
    str,
    num,
    // Levels
    succ,
    max,
    imax,
    param,
    // Exprs
    bvar,
    sort,
    @"const",
    app,
    lam,
    forallE,
    letE,
    proj,
    natVal,
    strVal,
    mdata,
    // Decls
    axiom,
    def,
    @"opaque",
    thm,
    quot,
    inductive,
};

// fn dispatchLine(
//     gpa: std.mem.Allocator,
//     line: []const u8,
//     names: *NameContext,
//     levels: *LevelContext,
//     // exprs: *ExprContext,
//     // decls: *Decls,
// ) !void {}
