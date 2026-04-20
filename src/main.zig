const std = @import("std");
const lean_zig = @import("lean_zig");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;

    var args = try init.minimal.args.iterateAllocator(alloc);
    defer args.deinit();

    const arg0 = args.next().?; // skip the first argument which is the path to the executable
    const file_path = if (args.next()) |arg| arg else {
        std.debug.print("Usage: {s} <path>\n", .{arg0});
        return;
    };

    const cwd = std.Io.Dir.cwd();

    std.debug.print("reading path: {s}\n", .{file_path});

    const file = try cwd.openFile(init.io, file_path, .{});
    defer file.close(init.io);

    var internal_buffer: [1024]u8 = undefined;
    var file_reader = file.reader(init.io, &internal_buffer);
    const reader = &file_reader.interface;

    var idx: usize = 0;

    const first_line = (try reader.takeDelimiter('\n')).?;

    const obj: std.json.Parsed(Header) = try std.json.parseFromSlice(Header, alloc, first_line, .{});
    defer obj.deinit();

    std.debug.print("Meta Header: {s}\n", .{first_line});

    std.debug.print("Parsed meta info: lean githash {s}\n", .{obj.value.meta.lean.githash});

    while (try reader.takeDelimiter('\n')) |line| : (idx = idx + 1) {
        const parsed_obj: std.json.Parsed(std.json.Value) = try std.json.parseFromSlice(std.json.Value, alloc, line, .{});
        defer parsed_obj.deinit();
        const line_obj = parsed_obj.value;

        std.debug.print("----------------\n", .{});
        std.debug.print("line {d}: {s}\n", .{ idx, line });
        std.debug.print("line type: {s}\n", .{line_obj.object.keys()[0]});
    }
}

const ExporterHeader = struct { name: []u8, version: []u8 };

const LeanHeader = struct { githash: []u8, version: []u8 };

const FormatHeader = struct { version: []u8 };

const MetaHeader = struct {
    exporter: ExporterHeader,
    lean: LeanHeader,
    format: FormatHeader,
};

const Header = struct { meta: MetaHeader };
