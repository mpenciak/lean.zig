const std = @import("std");
const root = @import("lean_zig");

const json = std.json;

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

    try processFile(io, gpa, file_path);

    // while (try reader.takeDelimiter('\n')) |line| : (idx += 1) {
    //     const parsed_obj =
    //         try json.parseFromSlice(json.Value, gpa, line, .{});
    //     defer parsed_obj.deinit();
    //
    //     const kind = root.parser.findKind(parsed_obj.value.object).?;
    //     std.debug.print("{}\n", .{kind});
    //     const line_obj = parsed_obj.value;
    //     const strnameraw =
    //         json.parseFromValue(root.data.IndexedStrName, gpa, line_obj, .{}) catch continue;
    //     defer strnameraw.deinit();
    //     std.debug.print("successfully parsed {}\n", .{strnameraw.value});
    // }
}

fn processFile(io: std.Io, gpa: std.mem.Allocator, path: []const u8) !void {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io); // TODO: Maybe move this somewhere else?

    var buffer: [4098]u8 = undefined;
    var file_reader = file.reader(io, &buffer);
    const reader = &file_reader.interface;

    const first_line = try reader.takeDelimiter('\n');
    const meta_obj = try json.parseFromSlice(root.meta.Header, gpa, first_line.?, .{});
    defer meta_obj.deinit();

    var line_number: usize = 1;

    var ctx_arena: std.heap.ArenaAllocator = .init(gpa);
    defer ctx_arena.deinit();
    const arena = ctx_arena.allocator();
    var context: root.context.Context = .{};

    while (try reader.takeDelimiter('\n')) |line| : (line_number += 1) {
        try parseLine(arena, gpa, &context, line);
    }
}

// TODO this
fn handleKind(comptime line_kind: root.parser.LineKind, arena: std.mem.Allocator, context: *root.context.Context, obj: json.Value) !void {
    const ParserTarget = line_kind.associatedType();
    const parsed = try json.parseFromValue(ParserTarget, arena, obj, .{});

    const constructor = @tagName(line_kind);
    const kind = comptime line_kind.toKind();
    const associated_type = kind.associateData();
    const value = @field(parsed.value, constructor);
    const item = @unionInit(associated_type, constructor, value);
    const ctx_field_name = @tagName(kind) ++ "s";

    try @field(context, ctx_field_name).append(arena, item);
    std.debug.print("parsed {}: {}\n", .{ line_kind, item });
}

fn parseLine(ctx_arena: std.mem.Allocator, gpa: std.mem.Allocator, context: *root.context.Context, line: []const u8) !void {
    const parsed_obj = try json.parseFromSlice(json.Value, gpa, line, .{});
    defer parsed_obj.deinit();
    const obj = parsed_obj.value;

    const kind = root.parser.findLineKind(obj.object).?;
    switch (kind) {
        // // Names
        // .str => {
        //     try handleKind(root.data.IndexedStrName, .str, ctx_arena, context, obj);
        // },
        // .num => {
        //     try handleKind(root.data.IndexedNumName, .num, ctx_arena, context, obj);
        // },
        // // Levels
        // .succ => {
        //     try handleKind(root.data.IndexedSuccLevel, .succ, ctx_arena, context, obj);
        // },
        // .max => {
        //     try handleKind(root.data.IndexedMaxLevel, .max, ctx_arena, context, obj);
        // },
        // .imax => {
        //     try handleKind
        // },
        inline else => |k| try handleKind(k, ctx_arena, context, obj),
        // std.debug.print("{}\n", .{kind}),
    }
}
