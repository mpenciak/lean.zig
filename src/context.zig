const std = @import("std");
const data = @import("data.zig");

pub const NameContext = struct {
    map: std.ArrayList(data.Name),

    pub fn init(allocator: std.mem.Allocator) !NameContext {
        const name_map: std.ArrayList(data.Name) = try .initCapacity(allocator, 50);

        return .{ .map = name_map };
    }

    pub fn deinit(self: *NameContext, allocator: std.mem.Allocator) void {
        self.map.deinit(allocator);
    }
};

pub const LevelContext = struct {
    map: std.ArrayList(data.Level),

    pub fn init(allocator: std.mem.Allocator) !LevelContext {
        const level_map: std.ArrayList(data.Level) = try .initCapacity(allocator, 50);
        return .{ .map = level_map };
    }

    pub fn deinit(self: *LevelContext, allocator: std.mem.Allocator) void {
        self.map.deinit(allocator);
    }
};

pub const ExprContext = struct {};

pub const Decls = struct {};

pub const Context = struct {};
