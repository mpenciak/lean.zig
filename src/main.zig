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

fn parseLine(ctx_arena: std.mem.Allocator, gpa: std.mem.Allocator, context: *root.context.Context, line: []const u8) !void {
    const parsed_obj = try json.parseFromSlice(json.Value, gpa, line, .{});
    defer parsed_obj.deinit();
    const obj = parsed_obj.value;

    const kind = root.parser.findLineKind(obj.object).?;
    switch (kind) {
        inline else => |k| try handleKind(k, ctx_arena, context, obj),
    }
}

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
