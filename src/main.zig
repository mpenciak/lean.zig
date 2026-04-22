const std = @import("std");
const json = std.json;
const lean_zig = @import("lean_zig");

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
        try json.parseFromSlice(Header, gpa, first_line, .{});
    defer obj.deinit();

    var name_context: NameContext = try .init(gpa);
    defer name_context.deinit(gpa);
    var level_context: LevelContext = try .init(gpa);
    defer level_context.deinit(gpa);

    while (try reader.takeDelimiter('\n')) |line| : (idx = idx + 1) {
        const parsed_obj =
            try json.parseFromSlice(json.Value, gpa, line, .{});
        defer parsed_obj.deinit();
        const line_obj = parsed_obj.value;
        const strnameraw =
            json.parseFromValue(StrName, gpa, line_obj, .{}) catch continue;
        defer strnameraw.deinit();
        std.debug.print("successfully parsed {}\n", .{strnameraw.value});
    }
}

// {
//     "num": {
//         "pre": integer,
//         "i": integer
//     }
//     "in": integer,
// }
const NumName = struct {
    num: NumNameInner,
    in: u32,
};
const NumNameInner = struct {
    pre: u32,
    i: u32,
};

// {
//     "str": {
//         "pre": integer,
//         "str": string
//     },
//     "in": integer,
// }
const StrName = struct {
    str: StrNameInner,
    in: u32,
};

const StrNameInner = struct {
    pre: u32,
    str: []const u8,
};

const Name = union(enum) {
    num: NumNameInner,
    str: StrNameInner,
};

const NameContext = struct {
    map: std.ArrayList(Name),

    fn init(allocator: std.mem.Allocator) !NameContext {
        const name_map: std.ArrayList(Name) = try .initCapacity(allocator, 50);

        return .{ .map = name_map };
    }

    fn deinit(self: *NameContext, allocator: std.mem.Allocator) void {
        self.map.deinit(allocator);
    }
};

const LevelExpr = union(enum) {
    // {
    //     "succ": integer
    //     "il": integer,
    // }
    succ: struct {
        inner: u32,
    },

    // {
    //     "max": [integer, integer],
    //     "il": integer,
    // }
    max: struct {
        left: u32,
        right: u32,
    },

    // {
    //     "imax": [integer, integer],
    //     "il": integer,
    // }
    imax: struct {
        left: u32,
        right: u32,
    },

    // {
    //     "param": integer,
    //     "il": integer,
    // }
    param: struct {
        param: u32,
    },
};

const LevelContext = struct {
    map: std.ArrayList(LevelExpr),

    fn init(allocator: std.mem.Allocator) !LevelContext {
        const level_map: std.ArrayList(LevelExpr) = try .initCapacity(allocator, 50);
        return .{ .map = level_map };
    }

    fn deinit(self: *LevelContext, allocator: std.mem.Allocator) void {
        self.map.deinit(allocator);
    }
};

const ExporterHeader = struct { name: []const u8, version: []const u8 };

const LeanHeader = struct { githash: []const u8, version: []const u8 };

const FormatHeader = struct { version: []const u8 };

const MetaHeader = struct {
    exporter: ExporterHeader,
    lean: LeanHeader,
    format: FormatHeader,
};

const Header = struct { meta: MetaHeader };
